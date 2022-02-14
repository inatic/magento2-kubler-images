The `nginx` master process reads configuration files and attaches to the relevant ports, after which it loads a number of worker processes that will do the actual processing of requests. By default there will be as many workers as there are processor cores on the server. Each worker handles events (e.g. incoming requests) as they turn up.

## Configuration

This `nginx` image loads with a basic configuration that can be found at `/etc/nginx/nginx.conf`. Directives at the end of this file include both all `.conf` files in the `/etc/nginx/conf.d/` directory, and all `.conf` files in the `/etc/nginx/sites-enabled/` directory. The first of these directories is typically used for general customization while the second is meant for site configurations, though they are basically treated in the same way.

```
include /etc/nginx/conf.d/*.conf;
include /etc/nginx/sites-enabled/*.conf;
```

## IPv6

Add `ipv6` support, it's the future.

```build.sh
update_use 'www-servers/nginx' '+http2 +ipv6'
```

## Timeout

Certain Magento2 scripts need a bit longer to execute and nginx's timeout setting needs to be sufficiently high for them to terminate and send back their response. A likely symptom of connections timing out is that `Varnish` will be unable to get a response from nginx (and the Magento2 pages running PHP code) and will display a message saying the backend is unavailable. Magento sets the timeout for Varnish to be 600 seconds in the `default.vcl` configuration, so we'll go with the same value for nginx.

```etc/nginx/nginx.conf
proxy_connect_timeout 600;
proxy_send_timeout 600;
proxy_read_timeout 600;
```

## Buffers

Nginx is positioned between the client (browser of the user) and the Magento2 installation. When it receive a response from Magento, this response is temporarily stored before sending back to the client. The response contains HTTP headers which are typically quite small, yet for Magento they can be big enough that the size of the buffer storing them needs to be increased. This is the buffer size that holds a single response, and if the buffer is full you will be presented with a *upstream sent too big header while reading response header from upstream* error message. Here the buffer value is doubled to 8k.

```etc/nginx/nginx.conf
proxy_buffer_size 8k;
```

## SSL Certificates

Nginx is used as a proxy server for receiving and redirecting incoming traffic. For this it needs to terminate HTTPS requests and thus requires an SSL certificate for the domain. It needs this certificate at startup, but the LetsEncrypt request process needs a running webserver. To get around this chicken-and-egg problem, `nginx` generates self-signed certificates at startup for each of the domains in the `certs` directory. Once the webserver is running, the `letsencrypt` container can replace these self-signed certificates with some that are signed by a proper authority. Properties for generating temporary certificates can be fed into the container using environment variables, though it really doesn't make much difference what they are as long as the certificate works.

```bash
for path in /etc/nginx/certs/*/ ; do
    dir=${path%*/}      # remove the trailing "/"
    d=${dir##*/}         # print everything after the final "/"
    # create self signed certs if needed
    if [ ! -f /etc/nginx/certs/${d}/domain.crt ] || [ ! -f /etc/nginx/certs/${d}/domain.key ]; then
        CRT_COUNTRY="${CRT_COUNTRY:-DE}"
        CRT_STATE="${CRT_STATE:-SA}"
        CRT_LOCACTION="${CRT_LOCACTION:-MD}"
        CRT_ORG="${CRT_ORG:-ACME Inc - nginx}"
        CRT_CN="${d%/}"
        # rsa cert
        openssl req -new -x509 -nodes -days 3650 -newkey rsa:4096 \
            -subj "/C=${CRT_COUNTRY}/ST=${CRT_STATE}/L=${CRT_LOCACTION}/O=${CRT_ORG}/CN=${CRT_CN}" \
            -keyout /etc/nginx/certs/${d}/domain.key \
            -out /etc/nginx/certs/${d}/domain.crt
        # ecc cert
        openssl ecparam -name secp521r1 -genkey -param_enc explicit -out /etc/nginx/certs/${d}/domain.ecc.key
        openssl req -new -x509 -nodes -days 3650  \
            -subj "/C=${CRT_COUNTRY}/ST=${CRT_STATE}/L=${CRT_LOCACTION}/O=${CRT_ORG}/CN=${CRT_CN}" \
            -key /etc/nginx/certs/${d}/domain.ecc.key \
            -out /etc/nginx/certs/${d}/domain.ecc.crt
    fi
done

```
[Last Build][packages]

[Nginx]: http://nginx.org/
[packages]: PACKAGES.md
