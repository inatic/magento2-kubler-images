> The image configurations in this repository are adapted from the examples on the [Github page of the developer of Kubler][kubler-images]. Additional information can be found there.

A typical Magento2 installation requires a number of software components to run, like a webserver, database, search engine ... You can have a look in the [Magento2 Devdocs][devdocs] to see what software components and versions are needed for a particular Magento2 version. Each installation needs quite a number of such components, and requirements might change with subsequent Magento2 versions. Therefore it would be no small advantage to be able to treat each of these components separately, not having to worry about how upgrading one affects the other, and maybe keeping multiple versions of the same component at hand when upgrading a Magento2 installation.
 
This is the advantage offered by packaging components in [Docker][docker] images, which are like small virtual filesystems that only contain the files needed for the component in question. Many images can exist on the same system (or on a remote repository like [DockerHub][dockerhub]), making it easy to experiment and switch out when needed. Docker images are built by adding files, and this is typically accomplished using a so-called `Dockerfile`. This file contains the name of the parent image from which to inherit files and folders, and commands for adding others as neede. Our build process will use a `Dockerfile` for each image, but at the center of the image build process will be another tool named [Kubler](kubler). This tool also prepares files for adding to an image, but it comes with a flavour of build scripts and a build environment based on [Gentoo](gentoo) that in my opinion makes it a little easier to maintain a collection of images. The folders in this repository contain Kubler build scripts for the components needed by Magento2. As the latter is a rolling installation, meaning you best keep up close to the latest version, the scripts will be updated as requirements change.

# BUILD SYSTEM

Building images require both `Docker` and `Kubler` to be installed, which on an Ubuntu (Debian) system can be done using the `install-docker.sh` and `install-kubler.sh` scripts that are part of this repository. Create a folder for holding the scripts and other things related to docker, then just clone this repository and run the scripts. The `ìnstall-docker.sh` script first removes any old Docker versions, and then adds `docker` as well as `docker-compose` and `docker-machine` to the system. Loading and connecting software components of the Magento2 installation is done using `docker-compose`, and `docker-machine` is a tool for deploying and running containers (images when they are active) to multiple hosts. The `install-kubler.sh` script then clones [Github][kubler] into the user's home directory, after which it adds the location to the user's `$PATH` variable so the `kubler` command can be run from any directory on the system. Kubler allows for auto-completion of commands, so this feature is added as well. 

```
mkdir /docker
cd /docker
git clone https://github.com/inatic/magento2-kubler-images inatic
cd inatic
sh docker-install.sh
sh kubler-install.sh
```

# BUILD PROCESS

The process of building images using Kubler starts by creating a container based on the Gentoo operating system, and it is in this container that the files and folders for our images will be generated. The builder container fittingly has been named `bob` and its configuration script can be found under `builder/bob`. The `builder` directory in fact is just a straight copy from the original developer's [kubler-images][] repository on Github, and most of the scripts in the `images` directory are based on the examples in this repository, possibly with some modification for use with Magento2.

Gentoo is a bit special compared to many other Linux distributions in that it builds packages from source code instead of fetching precompiled binaries from a server. It gets the instructions on how to build a package from `ebuild` scripts, an overview of which can be found at [packages.gentoo.org][packages.gentoo.org]. So, where the build container (`bob`) brings the first ingredient for making docker images, namely a functional toolchain, these `ebuilds` provide the instructions that have to be executed by the build container in order to generate the files and folders of a given software package. The `ebuilds` that can be found on Gentoo's website are also available from the so-called `Portage Tree`, which is nothing more than a collection of all the software title and version `ebuilds` that are available for Gentoo. `Portage` by the way is the build system used by Gentoo, and it's called a tree because `ebuilds` are hierarchically organized in folders by category.

The main reason for compiling software from source code is the ability to include and leave out features according to requirements, and Gentoo offers this possiblity with so-called `USE flags`. These are options that can be set for and entire system (e.g. to leave out graphics capabilities on a server with the `-X` USE flag) or for each package separately. In the `build.sh` script of the PHP image, a list for example can be found of all the features that are added to the entire system and one for the options that are enabled specifically for the PHP service.

```
update_use '+gif' '+jpeg' '+jpeg2k' '+png' '+tiff' '+webp'

update_use 'dev-lang/php' '+bcmath' '+calendar' '+cli' '+ctype' '+curl' '+exif' '+fpm' '+mhash' \
           '+ftp' '+iconv' '+imap' '+intl' '+json' '+mhash' '+mysql' '+mysqli' '+nls' '+opcache' '+pcntl' \
           '+pdo' '+simplexml' '+soap' '+sockets' '+sodium' '+ssl' '+truetype' '+wddx' '+webp' '+xml' '+xmlreader' \
           '+xmlrpc' '+xmlwriter' '+xpm' '+xslt' '+zip'
```

When a Kubler build process is started, the build container is prepared in case it doesn't exist yet, and the latest version of the `Portage Tree` is downloaded. At this point the container is ready for instructions on how to build a docker image. These instructions come from the `build.sh` script that can be found in the configuration folder of each image, under the `images` directory. This script specifies the packages that need to be installed, changes that are to be made before building, and changes that need to be applied after building. Packages are installed to an `${_EMERGE_ROOT}` directory on the build container, and at the end of the process they are added to an archive (`rootfs.tar`) containing the files and folders for the docker image. A `Dockerfile`, which can also be found in each image directory (or better a template to generate it, named `Dockerfile.template`, which contraty to the Dockerfile can be parameterized) then takes care of adding the files and folders in the `rootfs.tar` archive to the docker image. At this point the image is ready for use with Docker.

Another aspect of the image build process is that it is hierarchical, meaning that each image can have a parent image and inherit its files and folders. If you for example look at the `s6` image, which is used for service supervision (starting, stopping and observing the services running in a container) in all of our images, you can see it depends on the `busybox` and `glibc` containers. Busybox adds a range of basic Linux commands like `ls` and `cat`, and `glibc` adds the *GNU C Library*, providing all the critical APIs for a program to communicate with the Linux system. As the `s6` container inherits from the `glibc` container, which in turn inherits from the `busybox` container, all the files and folders in latter containers will also be included in the `s6` container. The parent of an image is configured in its `build.conf` file, which is also the place for storing custom variables affecting the build process. An image's dependency graph can be consulted using the `kubler dep-graph` command.

```
kubler dep-graph -r

   "scratch" -> "inatics/busybox"
   "inatics/busybox" -> "inatics/glibc"
   "inatics/glibc" -> "inatics/s6";
``` 

Kubler build scripts and stored in a so-called `namespace` which corresponds to the directory containing the `builder` and `images` folders. The content of this repository is thus a single namespace. Multiple namespaces can have different builders and configurations, and when a `kubler` command is executed inside a namespace folder it picks up the configuration file (if any) in that folder and references the `images` folder for that namespace.

# USING KUBLER

Kubler downloads an archive containing a kind of minimal Gentoo operating system (referred to as a `stage3` archive) to create its build container (`bob`). This archive is hosted on Gentoo's (mirror) servers and regularly updated. The `kubler update` command makes sure Kubler has the name of the latest stage3 archive and is therefore best executed before building any images. It also takes care of updating the `Portage` tree (containing `ebuild` scripts) which is stored in a separate container. 

```
kubler update
```

As building images can be quite time-consuming, kubler will try to avoid building images for which the result is already available (the `rootfs.tar` archive). Sometimes it's necessary to start from scratch and remove these so-called build `artifacts`, for example when making changes to the build script. The `kubler clean` command can take care of removing these.

```
kubler clean
```

Starting the actual build process of an image is rather simple, just execute `kubler build` followed by the name of the image as it appears in the `images` directory.

```
kubler build busybox
```

# PUSHING IMAGES TO DOCKERHUB

[Dockerhub][dockerhub] is a repository for storing images and the default place for Docker to go looking if an image is not available on the current system. It is quite practical to configure and build images on one server, then push them to dockerhub for safe keeping and easy access by other servers. Gentoo has a rolling release model, in which new packages become available and old packages (that might have bugs or unresolved security issues) are taken out of circulation. After some time it becomes difficult to build older versions of software packages; version 7.3.32 of PHP for example is the oldest supported version from [packages.gentoo.org][] at the time of writing. You should be keeping up to date with new version and avoid flawed versions anyway, so this probably is a good thing. Sometimes, however, it can come in quite handy to just fetch an old image from DockerHub and do whatever experimentation you have in mind. It is possible to get old versions of the *Portage Tree* and build from those, but depending on how old they are this can be a pain.

Some of the images in this repository (like `bash` and `busybox`) are only created as parents of other images and never needed by Magento2 themselves. The images that are needed by Magento2 are listed below, and only these will be pushed to DockerHub. For other images like `varnish` the officially released version is used, thhis also is available from DockerHub.

* nginx
* letsencrypt
* nginx-php
* mariadb
* redis
* elasticsearch 

[devdocs]: https://devdocs.magento.com/guides/v2.4/install-gde/system-requirements.html
[docker]: https://docs.docker.com/get-started/overview/
[dockerhub]: https://hub.docker.com/
[kubler]: https://github.com/edannenberg/kubler
[kubler-images]: https://github.com/edannenberg/kubler-images
[gentoo]: https://www.gentoo.org/
[packages.gentoo.org]: https://packages.gentoo.org
