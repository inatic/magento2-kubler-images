A typical Magento2 installation requires a number of software components to run, like a webserver, database, search engine ... You can have a look in the [Magento2 Devdocs][devdocs] to see what software components and versions are needed for a particular Magento2 version. Each installation needs quite a number of such components, and requirements might change with subsequent Magento2 versions. Therefore it would be no small advantage to be able to treat each of these components separately, not having to worry about how upgrading one affects the other, and maybe keeping multiple versions of the same component at hand when upgrading a Magento2 installation.
 
This is the advantage offered by packaging components in [Docker][docker] images, which are like small virtual filesystems that only contain the files needed for the component in question. Many images can exist on the same system (or on a remote repository like [DockerHub][dockerhub]), making it easy to experiment and switch out when needed. Docker images are built by adding files, and this is typically accomplished using a so-called `Dockerfile`. This file contains the name of the parent image from which to inherit files and folders, and commands for adding others as neede. Our build process will use a `Dockerfile` for each image, but at the center of the image build process will be another tool named [Kubler](kubler). This tool also prepares files for adding to an image, but it comes with a flavour of build scripts and a build environment based on [Gentoo](gentoo) that in my opinion makes it a little easier to maintain a collection of images. The folders in this repository contain Kubler build scripts for the components needed by Magento2. As the latter is a rolling installation, meaning you best keep up close to the latest version, the scripts will be updated as requirements change.

# BUILD SYSTEM

Building images require both `Docker` and `Kubler` to be installed, which on an Ubuntu (Debian) system can be done using the `install-docker.sh` and `install-kubler.sh` scripts that are part of this repository. Create a folder for holding the scripts and other things related to docker, then just clone this repository and run the scripts. The `ìnstall-docker.sh` script first removes any old Docker versions, and then adds `docker` as well as `docker-compose` and `docker-machine` to the system. Loading and connecting software components of the Magento2 installation is done using `docker-compose`, and `docker-machine` is a tool for deploying and running containers (images when they are active) to multiple hosts. The `install-kubler.sh` script then clones [Github][kubler] into the user's home directory, after which it adds the location to the user's `$PATH` variable so the `kubler` command can be run from any directory on the system. Kubler allows for auto-completion of commands, so this feature is added as well. 

```
mkdir /docker
cd /docker
git clone https://github.com/inatic/magento2-kubler-images
cd magento2-kubler-images
sh docker-install.sh
sh kubler-install.sh
```


[devdocs]: https://devdocs.magento.com/guides/v2.4/install-gde/system-requirements.html
[docker]: https://docs.docker.com/get-started/overview/
[dockerhub]: https://hub.docker.com/
[kubler]: https://github.com/edannenberg/kubler
[gentoo]: https://www.gentoo.org/
