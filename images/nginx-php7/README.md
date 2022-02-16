This image runs a `php-fpm` service, which is the PHP interpreter bundled in a way that the webserver can communicate with it. The acronym stands for *fastcgi process manager*, and `cgi` in turn stands for *common gateway interface* and provides the interface for the webserver to interact with other applications. In our case the `php-fpm` service creates a socket to which the `nginx` webserver can talk.

# PHP version

The first setting is the version of PHP that is compatible with the desired release of Magento2. On the DevDocs site you can find that [current release of Magento][release] as well as the [system requirements][requirements] for this release. On the Gentoo packages website you can furthermore find the [versions of PHP][gentoo-php] that are currently supported on Gentoo, with the `stable` versions in green and the `experimental` version in yellow. The version of PHP is configured in `build.conf` and used in the `build.sh` script to add the appropriate package to the image. In `Dockerfile.template` the version is furthermore passed into the container as an environment variable and from there used by the service `run` script to select the correct version of `php-fpm` for loading in the container.

```build.conf
BOB_PHP_SLOT='7.4'
```

# Iconv

`Iconv` is an application programming interface used for converting between character encondings (e.g. between ASCII and UTF-8) and is relied upon by PHP and Magento. It is installed in the `glibc` image (upon which this image builds), but most of the available character sets gets pruned before creating the root image (`rootfs.img`). This is avoided by commenting out the following line in the `build.sh` script of the `glibc` image.

```
# purge iconv
#rm -f "${_EMERGE_ROOT}"/usr/"${_LIB}"/gconv/*
```

# PHP extensions

Magento's extensions and settings for PHP can be found on the [DevDocs][requirements] website and can differ between versions, so have a look before upgrading your installation. Adding and removing software features in Gentoo (and thus for building images using `Kubler`) is done with USE-flags. Following are the flags required to add necessary PHP extensions, this is done in the `build.sh` script. 

```build.sh
update_use 'dev-lang/php' '+bcmath' '+calendar' '+cli' '+ctype' '+curl' '+exif' '+fpm' '+mhash' \
           '+ftp' '+iconv' '+imap' '+intl' '+json' '+mhash' '+mysql' '+mysqli' '+nls' '+opcache' '+pcntl' \
           '+pdo' '+simplexml' '+soap' '+sockets' '+sodium' '+ssl' '+truetype' '+wddx' '+webp' '+xml' '+xmlreader' \
           '+xmlrpc' '+xmlwriter' '+xpm' '+xslt' '+zip'
```

# PHP settings

Following options are set in the `build.sh` script. The PHP application (`php-fpm`) listens for requests at the `/run/php-fpm.sock` socket. The socket has `nginx` as its user and group because it needs to be accessed by the webserver (`nginx`). The `php-fpm` service in turn needs to be able to access PHP website files, and so it best also has `nginx` as both user and group, for non-php files in the website (e.g. images) need to be accessed by the webserver as well. The php-fpm service starts child processes for handling requests, the number of which is either static (all children are created at startup) or dynamic (extra children are created when more requests come in). The naming is a bit confusing, but according to [php documentation][php-fpm-config] the `servers` options below also refers to child processes. The `pm.start_servers` option sets the number to start from the beginning, and the `min_spare` and `max_spare` options set boundaries for dynamic allocation of child processes.

```build.sh
local fpm_conf
fpm_conf="${_EMERGE_ROOT}"/etc/php/fpm-php"${_php_slot}"/fpm.d/www.conf
sed-or-die '^listen = 127.0.0.1:9000' ';listen = 127.0.0.1:9000\nlisten = /run/php-fpm.sock' "${fpm_conf}"
sed-or-die '^;listen.owner = nobody' 'listen.owner = nginx' "${fpm_conf}"
sed-or-die '^;listen.group = nobody' 'listen.group = nginx' "${fpm_conf}"
sed-or-die '^user = nobody' 'user = nginx' "${fpm_conf}"
sed-or-die '^group = nobody' 'group = nginx' "${fpm_conf}"
sed-or-die '^pm.max_children = 5' 'pm.max_children = 50' "${fpm_conf}"
sed-or-die '^pm.start_servers = 2' 'pm.start_servers = 10' "${fpm_conf}"
sed-or-die '^pm.min_spare_servers = 1' 'pm.min_spare_servers = 5' "${fpm_conf}"
sed-or-die '^pm.max_spare_servers = 3' 'pm.max_spare_servers = 20' "${fpm_conf}"
```

The paths to files accessed by PHP can be cached, avoiding the effort of looking through the filesystem each time a page is loaded. This cache is sized using the `realpath_cache` variable, which is increased from its default value to improve performance. The suggestion to make this change can be found in the [php settings][php-settings] page on Magento DevDocs.

```
sed-or-die '^;realpath_cache_size =.*' "realpath_cache_size = 10M" "${fpm_php_ini}"
sed-or-die '^;realpath_cache_ttl =.*' "realpath_cache_ttl = 7200" "${fpm_php_ini}"
```

Requests to `php-fpm` are buffered into memory by the nginx webserver, and if the configured amount of memory runs out they are buffered on disk which is slower. The `fastcgi_buffer_size` configuration specifies how much memory is reserved for the HTTP header of each response, and the `fastcgi_buffers` option specifies how much memory is reserved for buffering response payloads. The first number in `fastcgi_buffers` is the number of segments and the second their size. The latter best corresponds to the system page size or a multiple of it. The page size of your system can be discovered by executing `getconf PAGESIZE` in the shell, it often is 4K, and so the following configuration reserves a total buffer size of 4MB. This configuration is currently also set in the `nginx.conf.sample` file used by Magento, so it might no longer be needed here.

```etc/nginx/php.conf
location ~ .php$ {
    fastcgi_buffer_size 256k;
    fastcgi_buffers 1024 4k;
}
```

# Magento user

When a request for a Magento PHP script comes in from the nginx webserver, it is executed with the privileges of the `nginx` user. When you as the administrator of the server/container execute a PHP script, it should not be executed as root because that would be dangerous. Therefore a `magento` user is created for executing the Magento CLI scripts (mainly from `bin/magento`) in the container. Magento files have ownership set to `magento/nginx` (user/group) so both the magento user can access the scripts from the CLI, and nginx can access scripts for requests coming from the web.

```build.sh
groupadd -g 1001 magento
useradd -u 1001 -g magento -d /home/magento -s /bin/sh magento
usermod -a -G 249 magento
mkdir -p "${_EMERGE_ROOT}"/home/magento
chown -R magento:magento "${_EMERGE_ROOT}"/home/magento
```

## MySQL client

A MySQL client is added so access to the database is available from inside the container. This way a single installation script can for example create the necessary tables in the database and proceed with the other steps necessary for setting up Magento. Credentials for the database are passed into the container as environment variables. The following is added to the `build.sh` script.

```build.sh
_packages="dev-db/mysql"
update_use 'dev-db/mysql' '-server'
```

# Nullmailer

Magento does not need a full fledged mail server, especially if it uses an external service like Gmail for sending and never needs to receive any emails. The nullmailer service is already included and can just be activated in `Dockerfile.template` by adding it to the `/service` directory provided by `s6`.

```bash
RUN chmod +x $(find /etc/service -name run) && \
    ln -s /etc/service/nullmailer /service && \
```

Set permissions and ownership for some of the files used by the nullmailer deamon in the run script (`etc/service/nullmailer/run`).

```bash
chmod 0640 /etc/nullmailer/remotes
chown root:nullmail /etc/nullmailer/*
```

# Entrypoint

Once the image is built (from `build.sh` and `Dockerfile.template` and with its `run` script set up) there might still be some configuration settings that differ between deployments, for example the amount of memory assigned to PHP or the specific timezone for the installation (though a global organization should probably just use `UTC`). The container goes straight to the run script when starting, and at the end of the run script the deamon for the service in question is loaded. Therefore the following lines of code are added before the end of the `run` script, they execute all scripts that are placed in a certain directory. This allows adding scipts to the directory and further customize the installation.


```etc/service/php-fpm/run
DIR=/entrypoint/php-fpm
echo "Configuring the container..."
if [[ -d "$DIR" ]]
then
    chmod +x ${DIR}/*
    /bin/run-parts --verbose "$DIR"
fi
```


[Last Build][packages]

[Nginx]: http://nginx.org/
[PHP]: http://php.org/
[FPM]: http://php-fpm.org/
[xdebug]: http://xdebug.org/
[adminer]: http://www.adminer.org/en/
[composer]: https://getcomposer.org/
[devdocs]: https://devdocs.magento.com/
[releases]: https://devdocs.magento.com/release/
[requirements]: https://devdocs.magento.com/guides/v2.4/install-gde/system-requirements.html
[gentoo-php]: https://packages.gentoo.org/packages/dev-lang/php
[php-fpm-config]: https://www.php.net/manual/en/install.fpm.configuration.php
[packages]: PACKAGES.md
