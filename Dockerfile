# Accepted values: 8.2 - 8.1
ARG PHP_VERSION=8.2
ARG COMPOSER_VERSION=2.5.8

###########################################
# PHP dependencies
###########################################

FROM composer:${COMPOSER_VERSION} AS vendor
WORKDIR /var/www/html
COPY composer* ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --ignore-platform-reqs \
    --optimize-autoloader \
    --apcu-autoloader \
    --ansi \
    --no-scripts \
    --audit

###########################################
# Front-end dependencies
###########################################
FROM node:20 as node

ENV ROOT=/var/www/html
WORKDIR ${ROOT}

COPY --from=vendor ${ROOT}/vendor/ vendor/
COPY resources/ ./resources/
COPY storage/ ./storage/
COPY public/ ./public/

COPY package*.json \
    vite.config.js \
    tailwind.config.js \
    postcss.config.js \
    tsconfig.json \
    ./

RUN npm install && npm run build


###########################################
FROM php:${PHP_VERSION}-apache
LABEL maintainer="I4T CRM Dev Team <crm-dev@insurance4truck.com>"

WORKDIR /var/www/html

ARG WWWUSER=1000
ARG WWWGROUP=1000
ARG TZ=UTC

ARG CONTAINER_MODE=app
ARG APP_WITH_SCHEDULER=true
ARG DOCUMENT_ROOT=/var/www/html/public

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm-color \
    DOCUMENT_ROOT=${DOCUMENT_ROOT} \
    CONTAINER_MODE=${CONTAINER_MODE} \
    APP_WITH_SCHEDULER=${APP_WITH_SCHEDULER}

ENV ROOT=/var/www/html

RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

RUN apt-get update; \
    apt-get upgrade -yqq; \
    pecl -q channel-update pecl.php.net; \
    apt-get install -yqq --no-install-recommends --show-progress \
        curl \
        wget \
        libcurl4-openssl-dev \
        ca-certificates \
        libmemcached-dev \
        libz-dev \
        libbrotli-dev \
        libpq-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
        libssl-dev \
        libwebp-dev \
        libmcrypt-dev \
        libonig-dev \
        libzip-dev zip unzip \
        libargon2-1 \
        libidn2-0 \
        libpcre2-8-0 \
        libpcre3 \
        libxml2 \
        libzstd1 \
        procps \
        libbz2-dev \
        pdftk-java

# Copy my.ini file
COPY docker-conf/config/php/my.ini /usr/local/etc/php/conf.d/        

###########################################
# Configure Apache
###########################################
RUN sed -ri -e 's!/var/www/html!${DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

RUN a2enmod rewrite

# PHP files should be handled by PHP, and should be preferred over any other file type
RUN { \
		echo '<FilesMatch \.php$>'; \
		echo '\tSetHandler application/x-httpd-php'; \
		echo '</FilesMatch>'; \
		echo; \
		echo 'DirectoryIndex disabled'; \
		echo 'DirectoryIndex index.php index.html'; \
		echo; \
		echo '<Directory ${DOCUMENT_ROOT}>'; \
		echo '\tOptions -Indexes'; \
		echo '\tAllowOverride All'; \
		echo '</Directory>'; \
		echo; \
		echo 'SetEnvIf x-forwarded-proto https HTTPS=on'; \
	} | tee "$APACHE_CONFDIR/conf-available/docker-php.conf" \
	&& a2enconf docker-php

###########################################

RUN groupadd --force -g $WWWGROUP laravel \
    && useradd -ms /bin/bash --no-log-init --no-user-group -g $WWWGROUP -u $WWWUSER laravel

###########################################
# bzip2
###########################################

RUN docker-php-ext-install bz2;

###########################################
# pdo_mysql
###########################################

RUN docker-php-ext-install pdo_mysql;

###########################################
# zip
###########################################

RUN docker-php-ext-configure zip && docker-php-ext-install zip;

###########################################
# mbstring
###########################################

RUN docker-php-ext-install mbstring;

###########################################
# GD
###########################################

RUN docker-php-ext-configure gd \
            --prefix=/usr \
            --with-jpeg \
            --with-webp \
            --with-freetype \
    && docker-php-ext-install gd;

###########################################
# OPcache
###########################################

ARG INSTALL_OPCACHE=true

RUN if [ ${INSTALL_OPCACHE} = true ]; then \
      docker-php-ext-install opcache; \
  fi

###########################################
# PHP Redis
###########################################

ARG INSTALL_PHPREDIS=true

RUN if [ ${INSTALL_PHPREDIS} = true ]; then \
      pecl -q install -o -f redis \
      && rm -rf /tmp/pear \
      && docker-php-ext-enable redis; \
  fi

###########################################
# PCNTL
###########################################

ARG INSTALL_PCNTL=true

RUN if [ ${INSTALL_PCNTL} = true ]; then \
      docker-php-ext-install pcntl; \
  fi

###########################################
# BCMath
###########################################

ARG INSTALL_BCMATH=true

RUN if [ ${INSTALL_BCMATH} = true ]; then \
      docker-php-ext-install bcmath; \
  fi

###########################################################################
# Human Language and Character Encoding Support
###########################################################################

ARG INSTALL_INTL=true

RUN if [ ${INSTALL_INTL} = true ]; then \
      apt-get install -yqq --no-install-recommends --show-progress zlib1g-dev libicu-dev g++ \
      && docker-php-ext-configure intl \
      && docker-php-ext-install intl; \
  fi

###########################################
# Memcached
###########################################

ARG INSTALL_MEMCACHED=false

RUN if [ ${INSTALL_MEMCACHED} = true ]; then \
      pecl -q install -o -f memcached && docker-php-ext-enable memcached; \
  fi

###########################################

RUN apt-get clean
RUN docker-php-source delete
RUN rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
RUN rm /var/log/lastlog /var/log/faillog

COPY . .
COPY --from=node ${ROOT}/public/ public/
COPY --from=vendor ${ROOT}/vendor/ vendor/
COPY --from=vendor ${ROOT}/composer.json ./

RUN mkdir -p bootstrap/cache
RUN chown -R laravel:laravel \
  storage \
  bootstrap/cache \
  && chmod -R ug+rwx storage bootstrap/cache

RUN chmod +x docker-conf/config/start.sh

USER laravel

ENTRYPOINT ["docker-conf/config/start.sh"]