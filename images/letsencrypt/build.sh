#
# Kubler phase 1 config, pick installed packages and/or customize the build
#
_packages=""
#_keep_headers=true

configure_bob()
{
    :
}

#
# This hook is called just before starting the build of the root fs
#
configure_rootfs_build()
{
    # add user/group for unprivileged container usage
    groupadd -g 404 letsencrypt
    useradd -u 4004 -g letsencrypt -d /home/letsencrypt letsencrypt
    mkdir -p "${_EMERGE_ROOT}"/home/letsencrypt
    chown -R letsencrypt:letsencrypt "${_EMERGE_ROOT}"/home/letsencrypt
    # installing acme-tiny
    mkdir -p "${_EMERGE_ROOT}"/usr/bin/acme-tiny
    wget -O - https://raw.githubusercontent.com/diafygi/acme-tiny/master/acme_tiny.py > "${_EMERGE_ROOT}"/usr/bin/acme-tiny/acme_tiny.py
}

#
# This hook is called just before packaging the root fs tar ball, ideal for any post-install tasks, clean up, etc
#
finish_rootfs_build()
{   
    mkdir -p "${_EMERGE_ROOT}"/certificates
    chown -R letsencrypt:letsencrypt "${_EMERGE_ROOT}"/certificates
    mkdir -p "${_EMERGE_ROOT}"/challenge
    chown -R letsencrypt:letsencrypt "${_EMERGE_ROOT}"/challenge
}
