# Discourse wrapper for Railway. The official image runs nginx, unicorn and sidekiq in one container (runit, /sbin/boot) and
# listens on 80, but Railway's healthcheck and edge dial the injected PORT, so the wrapper rewrites nginx's listener to $PORT,
# hands the /shared volume to upstream's discourse uid, checks the database, Redis and host settings from Railway's variables,
# and creates the first administrator, its API key and a closed sign-up once the app answers. The literals a deployer should
# never have to type are baked in here.
#
# The upstream image is FLATTENED into a single layer (FROM scratch + COPY --from). Its release layers delete thousands of files
# that an earlier layer wrote (OCI whiteouts) and Railway ignores whiteouts, so a plain FROM revives them: on Railway the deleted
# plugins/blog/plugin.rb came back and the app refused to start ("INCOMPATIBLE PLUGIN ... register_homepage"), while the same
# image booted on a local docker.
# upstream: discourse/discourse
FROM discourse/discourse:2026.11.0-latest.2@sha256:b762c0ce618d6311c78153c32a3301b7193554f37dc47cea029729f9a078a8c1 AS upstream

# upstream: none flattened copy of the pinned upstream stage above
FROM scratch
COPY --from=upstream / /

COPY --chmod=0755 boot.sh /railway-boot.sh
COPY --chmod=0644 bootstrap.rb /railway-bootstrap.rb
COPY --chmod=0644 closed-signup.conf /etc/nginx/conf.d/outlets/server/25-closed-signup.conf

# upstream's own ENV (a scratch base inherits none), then the wrapper's
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RUBY_VERSION=4.0.10 \
    PG_MAJOR=18 \
    PG_MAJOR_OLD=15 \
    RUBY_ALLOCATOR=/usr/lib/libjemalloc.so \
    LEFTHOOK=0 \
    DEBIAN_RELEASE=trixie \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8 \
    RAILS_ENV=production \
    CREATE_DB_ON_BOOT=1 \
    DISABLE_LETSENCRYPT=1 \
    RUBY_GC_HEAP_GROWTH_MAX_SLOTS=40000 \
    RUBY_GC_HEAP_INIT_SLOTS=400000 \
    RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=1.5 \
    MIGRATE_ON_BOOT=1 \
    PRECOMPILE_ON_BOOT=1 \
    UNICORN_WORKERS=2 \
    UNICORN_SIDEKIQS=1 \
    DISCOURSE_DB_PORT=5432 \
    DISCOURSE_REDIS_PORT=6379 \
    DISCOURSE_DB_NAME=discourse \
    DISCOURSE_DB_USERNAME=discourse
EXPOSE 8080
ENTRYPOINT ["/railway-boot.sh"]
CMD ["/sbin/boot"]
