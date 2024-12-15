#!/usr/bin/env bash
set -e

container_mode=${CONTAINER_MODE:-app}

initialStuff() {
    php artisan package:discover --ansi; \
    php artisan event:cache; \
    php artisan config:cache; \
    php artisan route:cache;
}

if [ "$1" != "" ]; then
    exec "$@"
elif [ ${container_mode} = "app" ]; then
    initialStuff
    exec apache2-foreground
elif [ ${container_mode} = "scheduler" ]; then
    initialStuff
    exec php artisan schedule:work
elif [ ${container_mode} = "horizon" ]; then
    initialStuff
    exec php artisan horizon
else
    echo "Container mode mismatched."
    exit 1
fi