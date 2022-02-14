> The image configurations in this repository are adapted from examples on the [Github page of the developer of Kubler][kubler-images]. Additional information about both `Kubler` and the images can be found there.

A typical Magento2 installation requires a number of software components to run, like a webserver, database, search engine ... You can have a look in the [Magento2 Devdocs][devdocs] to see what software components and versions are needed for a particular Magento2 version. Each installation needs quite a number of such components, and requirements might change with subsequent Magento2 versions. It would be no small advantage to be able to treat each of these components separately, not having to worry about how upgrading one affects the other, and keeping multiple versions of the same component at hand when upgrading a Magento2 installation.
 
This is the advantage offered by packaging components in [Docker][docker] images, which are like small virtual filesystems that only contain the files needed for the component in question. Many images can exist on the same system (or on a remote repository like [DockerHub][dockerhub]), making it easy to experiment and switch between components when needed. Docker images are built by adding files, and this is typically accomplished using a so-called `Dockerfile`. This file contains the name of the parent image from which it inherits files and folders, and commands for adding other pieces of software as needed. The build process explained here will use a `Dockerfile` for each image, but at the center of the image build process will be another tool named [Kubler](kubler). This tool also prepares files for adding to an image, but it comes with a flavour of build scripts and a build environment based on [Gentoo](gentoo) that in my opinion makes it a little more suited for maintaining a collection of images like in this case for Magento2. As the latter is a rolling installation (meaning you best keep up close to the latest version), image configurations will be updated as requirements change.

# BUILD SYSTEM

When on a freshly installed server, start of by setting up `git` and any other tools you might rely on. In the following commands `vim` is an editor that works well in the terminal, and `tmux` is a terminal multiplexer, meaning it allows to create multiple terminals in the same session. `Vundle` is a package manager for vim (it allows installing extensions) and `dotfiles` in this case are configuration files. 

```
apt install --assume-yes git
git config --global user.name "Your Name"
git config --global user.email "you@yourmail.com"

apt remove --assume-yes vim-tiny
apt update
apt install --assume-yes vim
apt install --assume-yes vim-nox
cd ~
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
git clone https://github.com/inatic/dotfiles
cp dotfiles/.vimrc .
cp dotfiles/.tmux .
```

Both `Docker` and `Kubler` are required for generating images, which on Ubuntu (Debian) can be done using the `install-docker.sh` and `install-kubler.sh` scripts that are part of this repository. Create a folder for holding the scripts and other things related to docker, then just clone this repository and run the scripts. The `ìnstall-docker.sh` script first removes any old Docker versions and then adds `docker` as well as `docker-compose` and `docker-machine` to the system. Loading and connecting software components of the Magento2 installation is done using `docker-compose`, and `docker-machine` is a tool for deploying and running containers (images when they are active) to multiple hosts. The `install-kubler.sh` script clones [Github][kubler] into the user's home directory, after which it adds that location to the user's `$PATH` variable so the `kubler` command can be run from any directory on the system. Kubler allows for auto-completion of commands, so this feature is added as well.

```
mkdir /docker
cd /docker
git clone https://github.com/inatic/magento2-kubler-images inatics
cd inatics
sh docker-install.sh
sh kubler-install.sh
```

# BUILD PROCESS

The process of building images using Kubler starts by creating a container based on the Gentoo operating system, it is in this container that the files and folders for images will be generated. The builder container fittingly has been named `bob` by Kubler and its configuration script can be found under `builder/bob`. The `builder` directory in fact is just a straight copy from the original developer's [kubler-images][] repository on Github, and most of the scripts in the `images` directory are based on the examples in this repository, possibly with some modification for use with Magento2.

Gentoo is a bit special compared to many other Linux distributions in that it builds packages from source code instead of fetching precompiled binaries from a server. It gets the instructions on how to build a package from `ebuild` scripts, an overview of which can be found at [packages.gentoo.org][packages.gentoo.org]. Where the build container (`bob`) brings the first ingredient for making docker images, namely a functional toolchain, these `ebuilds` provide the instructions that are executed by the build container in order to generate the files and folders of a given software package. The `ebuilds` that can be found on Gentoo's website are also available from the so-called `Portage Tree`, which is nothing more than a collection of all the (software title and version) `ebuilds` that are available for Gentoo. `Portage` by the way is the build system used by Gentoo, and it's called a tree because `ebuilds` are hierarchically organized in folders by category.

The main reason for compiling software from source code is the ability to include and leave out features according to requirements, and Gentoo offers this possiblity with so-called `USE flags`. These are options that can be set for and entire system (e.g. to leave out graphics capabilities on a server with the `-X` USE flag) or for each package separately. In the `build.sh` script of the PHP image, a list for example can be found of all the features that are added to the entire system and one for the options that are enabled specifically for the PHP service.

```
update_use '+gif' '+jpeg' '+jpeg2k' '+png' '+tiff' '+webp'

update_use 'dev-lang/php' '+bcmath' '+calendar' '+cli' '+ctype' '+curl' '+exif' '+fpm' '+mhash' \
           '+ftp' '+iconv' '+imap' '+intl' '+json' '+mhash' '+mysql' '+mysqli' '+nls' '+opcache' '+pcntl' \
           '+pdo' '+simplexml' '+soap' '+sockets' '+sodium' '+ssl' '+truetype' '+wddx' '+webp' '+xml' '+xmlreader' \
           '+xmlrpc' '+xmlwriter' '+xpm' '+xslt' '+zip'
```

When a Kubler build process is started, the build container is prepared in case it doesn't exist yet, and the latest version of the `Portage Tree` is downloaded. At this point the container is ready for instructions on how to build a docker image. These instructions come from the `build.sh` script that can be found in the configuration folder of each image, under the `images` directory. This script specifies the packages that need to be installed, changes that are to be made before building, and changes that need to be applied after building. Packages are installed to an `${_EMERGE_ROOT}` directory on the build container, and at the end of the process they are added to an archive (`rootfs.tar`) containing the files and folders for the docker image. A `Dockerfile`, which can also be found in each image directory (or better a template to generate it, named `Dockerfile.template`, which contrary to the Dockerfile can be parameterized) then takes care of adding the files and folders in the `rootfs.tar` archive to the docker image. At this point the image is ready for use with Docker.

Another aspect of the image build process is that it is hierarchical, meaning that each image can have a parent image and inherit its files and folders. If you for example look at the `s6` image, which is used for service supervision (starting, stopping and observing services) in all of our images, you can see it depends on the `busybox` and `glibc` containers. Busybox adds a range of basic Linux commands like `ls` and `cat`, and `glibc` adds the *GNU C Library*, providing all the critical APIs for a program to communicate with the Linux system. As the `s6` container inherits from the `glibc` container, which in turn inherits from the `busybox` container, all the files and folders in latter containers will also be included in the `s6` container. The parent of an image is configured in its `build.conf` file, which is also the place for storing custom variables affecting the build process. An image's dependency graph can be consulted using the `kubler dep-graph` command.

```
kubler dep-graph -r s6

   "scratch" -> "inatics/busybox"
   "inatics/busybox" -> "inatics/glibc"
   "inatics/glibc" -> "inatics/s6";
``` 

Kubler build scripts are stored in a so-called `namespace` which corresponds to the directory containing the `builder` and `images` folders. The content of this repository is thus a single namespace. Multiple namespaces can have different builders and configurations, and when a `kubler` command is executed inside a namespace folder it picks up the configuration file in that folder and references the `images` folder for that namespace.

# KUBLER CONFIGURATION

Configurations are stored in `kubler.conf` files and can be found at multiple location on the system. The first location Kubler will look is `/etc/kubler.conf`, though with a Github installation this file will not be present. The second location is the installation directory with the file being `~/kubler/kubler.conf`. This file contains a lot of comments explaining available configuration options. A third location is Kubler's data directory, which is where Gentoo `stage3` archives and `distfiles` are saved, as well as the kubler namespace. This file can be found at `~/.kubler/kubler.conf`. The last location for a configuration file is in the namespace directory itself. Tags for images can for example be (manually of automatically) set to the current date.

```kubler.conf
IMAGE_TAG="$(date +'%Y%m%d')"
#IMAGE_TAG="20220213"
```

# USING KUBLER

Kubler downloads an archive containing a kind of minimal Gentoo operating system (referred to as a `stage3` archive) to create its build container (`bob`). This archive is hosted on Gentoo's (mirror) servers and regularly updated. The `kubler update` command makes sure Kubler has the name of the latest stage3 archive and is therefore best executed before building images. It also takes care of updating the `Portage` tree (containing `ebuild` scripts) which is stored in a separate container. 

```
cd inatics
kubler update
```

As building images can be quite time-consuming, kubler will try to avoid building images for which the result is already available (the `rootfs.tar` archive). Sometimes it's necessary to start from scratch and remove these so-called build `artifacts`, for example when making changes to the build script. The `kubler clean` command can take care of removing these.

```
kubler clean
```

Starting the actual build process of an image is rather simple, just execute `kubler build` followed by the name of the image as it appears in the `images` directory. When specifying the namespace (here `inatics`), all images contained therein will be built.

```
kubler build busybox
kubler build inatics
```

# PUSHING IMAGES TO DOCKERHUB

[Dockerhub][dockerhub] is a repository for storing images and the default place for Docker to go looking if an image can't be found on the system. It is quite practical to configure and build images on one server, then push them to dockerhub for safe keeping and easy access by other servers. Gentoo has a rolling release model, in which new packages become available and old packages (that might have bugs or unresolved security issues) are taken out of circulation. After some time it becomes difficult to build older versions of software packages; version 7.3.32 of PHP for example is the oldest supported version from [packages.gentoo.org][] at the time of writing. You should be keeping up to date and avoid flawed versions anyway, so this probably is a good thing. Sometimes, however, it can come in quite handy to just fetch an old image from DockerHub and do whatever experimentation you have in mind. It is possible to get old versions of the *Portage Tree* and build from those, but depending on how old they are this can be a pain.

Some of the images in this repository (like `bash` and `busybox`) are only created as parents of other images and never needed directly by themselves. Below list of images are directly used by Magento and only these will be pushed to DockerHub. For some images (e.g. `varnish`) the officially released version is used, which also is available from DockerHub.

* elasticsearch 
* letsencrypt
* mariadb
* nginx
* nginx-php
* redis

When DockerHub credentials are provided (in `push.conf` at the root of the namespace), the `kubler push` command can be used to store images in the repository.

```bash
DOCKER_LOGIN=myacc
DOCKER_PW=mypassword
#DOCKER_EMAIL=foo@bar.net
```

Both the current date and the `latest` tags are then uploaded to DockerHub with following commands:

```bash
kubler push elasticsearch
kubler push letsencrypt
kubler push mariadb
kubler push nginx
kubler push nginx-php7
kubler push redis
```

# OVERVIEW OF IMAGES

The Magento stack makes use of the following images:

| bash          	|
| busybox       	|
| elasticsearch 	|
| gcc           	| changed
| glibc         	| changed
| jre-openjdk   	|
| letsencrypt   	| new
| mariadb       	|
| nginx         	| changed
| nginx-php7    	| changed
| openssl       	|
| python3       	|
| redis         	| changed
| s6            	|

## BASH

[Bash][bash] is a so-called shell environment, it provides commands for interacting with the system.

[bash]: https://www.gnu.org/software/bash/

## BUSYBOX

[BusyBox][busybox] offers a replacement for most of the common Unix utilities in a single small package typically available under `/bin/busybox`. Commands can be accessed either as arguments to the busybox binary, or from symbolic links to this binary named after the command. In Gentoo the package installing busybox is `sys-apps/busybox`, and the USE-flag `+make-symlinks` created the symbolic links. The busybox image cam be loaded by itself, if you don't have it on your system it will be loaded from the `kubler` namespace on [DockerHub][dockerhub].

```
docker run -it --rm kubler/busybox
```

Once in the container, execute the `busybox` binary to get an overview of available commands. Use `exit` to leave the container.

```
busybox
exit
```

[busybox]: http://busybox.net/
[dockerhub]: https://hub.docker.com/u/kubler

## ELASTICSEARCH

[Elasticsearch][elasticsearch] is an open-source, RESTful, distributed search and analytics engine built on top of Apache Lucene. It is at the heart of the so-called *Elastic Stack*, which lets you take data from any source, in any format, and search, analyze, and visualize it. A single elasticsearch container can be run as deamon (`-d`) using the first of following commands, and an interactive session opened on it by the second command. Being a deamon the container will stay alive after the interactive session is closed and needs to be stopped manually, cleanup however is automatic thanks to the `-rm` option.

```
docker run -d --name mysearch --rm kubler/elasticsearch
docker exec -it mysearch bash
docker container stop mysearch
```

### Linking

Though we'll be setting up our Magento2 environment with `docker-compose`, it is straightforward to test the `elasticsearch` container just by loading it together with a busybox container and sending a request from the latter to the former. Containers need to be linked in order for one to be accessible to the other, this is why the `--link mysearch` option is added to the run command of the busybox container.

```
docker run -d --name mysearch --rm kubler/elasticsearch
docker run --link mysearch -it kubler/busybox
    wget --quiet -O - "http://mysearch:9200/"
```

### Changes

Elasticsearch uses an [mmapfs][mmapfs] directory for storing indices, and the limit placed by the host system on such directories is on the low side for elasticsearch. Execute `sysctl vm.max_map_count` to show the number of memory locations available, this number can be increased to what elasticsearch documentation recommends by updating the setting in `/etc/sysctl.conf`, after which a system and docker restart is necessary.

```
sysctl vm.max_map_count
    vm.max_map_count = 65530
echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
sysctl --system
systemctl restart docker
sysctl vm.max_map_count
    vm.max_map_count = 262144
```

[elasticsearch]: http://www.elasticsearch.org/
[mmapfs]: https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
[linking]: http://docs.docker.io/en/latest/use/port_redirection/#linking-a-container

## GCC

This is a collection of compilers and development tools for linguages like C and C++.

### Changes

Headers and static libs are imported from same namespace instead of from `kubler`.
```build.sh
_headers_from=inatics/glibc
_static_libs_from=inatics/glibc
```

## GLIBC

[Glibc][glibc] started out as the GNU Project's implementation of the C standard library, with full C++ support being added at a later point. The library provides core functions for GNU/Linux systems like `open`, `read`, `write`, `malloc`, `printf`, `login`, `exit` ... with available functions being POSIX and BSD compliant. The C library image is mostly used as a parent for other images, however it can also be used as a stand-alone when a program needs access to some glibc functions. Library files are installed in the `/lib64` directory.

### Changes

Iconv is a library used for converting between character sets and is added by the `glibc` container, but most of the encodings are purged when creating the root filesystem (`rootfs.tar`). For Magento the `php` container needs more than the basic character sets that are left, so comment out the purging command. This is done in `images/glibc/build.sh`.

```build.sh
# purge iconv
#rm -f "${_EMERGE_ROOT}"/usr/"${_LIB}"/gconv/*
```

[glibc]: https://www.gnu.org/software/libc/

## JAVA RUNTIME ENVIRONMENT

Java is a architecture-independent language so it can be executed on any system. It accomplishes this by compiling programs into so-called bytecode using the java compiler (`javac`) and executing them on any given platform using a java virtual machine (`JVM`) which translates bytecode into platform-specific instructions. The java runtime environment (`JRE`) that is added to this image bundles a java virtual machine with a set of libraries (`jars`) and other components used for running Java programs. The Java Runtime Environment (JRE) is downloaded from oracle, and the build script (`build.sh`) creates an unprivileged `java` user for executing code.

[Java]: https://openjdk.java.net/

## LETSENCRYPT

[Let's Encrypt][letsencrypt] is a free and automated certificate authority for generating SSL certificates. These are used to validate that a server is the legitimate destination of a domain name, so if you browse to for example `linux.org` the certificate will affirm that the server on the other end indeed belongs with the domain name.

[letsencrypt]: https://letsencrypt.org/

## MARIADB

[MariaDB][mariadb] is a relational database system and a further development of MySQL.

### Changes

Magento [DevDocs][devdocs] ask for MariaDB version 10.4 while a newer version is available in the Gentoo packages. As it's difficult to know if those versions are compatible with regards to Magento, so the older version is used.

```
_packages="dev-db/mariadb:10.4"
```

[mariadb]: https://mariadb.org/
[requirements]: https://devdocs.magento.com/guides/v2.4/install-gde/system-requirements.html

## NGINX

[Nginx][nginx] is a webserver that is mainly used for responding to hypertext transfer protocol (`HTTP`) requests but can also be used with other protocols like `SMTP` (for email).

[nginx]: http://nginx.org/

## PHP-FPM

[PHP-FPM][php-fpm] is a PHP interpreter bundled in a way that the webserver can communicate with it. The acronym stands for *fastcgi process manager*, and `cgi` in turn stands for *common gateway interface* and provides the interface for the webserver to interact with other applications. In our case the `php-fpm` service creates a socket to which the `nginx` webserver can talk.

[php-fpm]: http://php-fpm.org/

## OPENSSL

[OpenSSL][openssl] is a library for cryptography and an open-source implementation of the transport layer security (`TLS`) protocol. It is amongst other things used to create both self-signed and LetsEncrypt certificates.

[openssl]: https://www.openssl.org/

## PYTHON

[Python][python] is a programming language that is fun to use, versatile, and integrates with a huge range of libraries and applications. Here it is used for the [acme-tiny][acme-tiny] script, which interacts with LetsEncrypt to request certificates for the site. 

[python]: https://www.python.org/
[acme-tiny]: https://github.com/diafygi/acme-tiny

## REDIS

[Redis][redis] is a key-value data structure that is held in memory and therefore very fast. In Magento it is used for both backend and session caching.

[redis]: https://redis.io/

## S6 

[S6][s6] is a service supervision suite and in most containers provides the root process that brings up other services.

[s6]: https://skarnet.org/software/s6/index.html


[devdocs]: https://devdocs.magento.com/guides/v2.4/install-gde/system-requirements.html
[docker]: https://docs.docker.com/get-started/overview/
[dockerhub]: https://hub.docker.com/
[kubler]: https://github.com/edannenberg/kubler
[kubler-images]: https://github.com/edannenberg/kubler-images
[gentoo]: https://www.gentoo.org/
[packages.gentoo.org]: https://packages.gentoo.org
