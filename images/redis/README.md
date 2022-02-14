## kubler/redis

Run this [Redis][] image with:

    $ docker run -d --name redis-0 -p 6379:6379 kubler/redis

To test the server:

    $ docker run -it --rm --link redis-0:redis kubler/redis /usr/bin/redis-cli -h redis ping

## Changes

For redis the maximum available memory needs to be increased, as well as the strategy for what to do when this memory becomes full. The following has the `build.sh` script update the configuration settings in `/etc/redis.conf`, it increases maximum available memory and sets the eviction policy to `volatile-lru`. What the latter means is that when memory becomes scarce, the least recently used (LRU) keys will be evicted, but only the keys that have `expire` set. More information about this can be found in the [lru-cache section][lru-cache] on the redis website. 

```build.sh
finish_rootfs_build()
{
    sed-or-die '^maxmemory .*' 'maxmemory 4GB' "${_EMERGE_ROOT}"/etc/redis.conf
    sed-or-die '^maxmemory-policy .*' 'maxmemory-policy volatile-lru' "${_EMERGE_ROOT}"/etc/redis.conf
}

```

[Last Build][packages]

[Redis]: http://redis.io/
[lru-cache]: https://redis.io/topics/lru-cache
[packages]: PACKAGES.md
