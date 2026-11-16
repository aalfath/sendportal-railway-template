# SendPortal on Railway
# Upstream ships no official Docker image, so this builds the tagged release
# (https://github.com/mettle/sendportal) on the official PHP Apache image.
FROM composer:2.11.2@sha256:0c8e663f14c94d07b3c45b175c51f5a14718508f21fe4dd7e54f09488dd0ed71 AS composer

FROM php:8.4.27-apache-trixie@sha256:884f64b47174de2c0e813270fe7b24a18605729fcebe201302d98c38805530d0

ARG SENDPORTAL_VERSION=4.0.0.1
ARG SENDPORTAL_SHA256=d4abb82f756b029f40eb78282448ebad0ac1d95b024ba15445a2bbcfde5dc315
ARG PHPREDIS_VERSION=6.3.0
ARG PHPREDIS_SHA256=cb8f81df1a275599e4f8ddcfec7e1f65ed1953e6f5673649149fd680ebff4cad

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends libpq-dev libicu-dev libzip-dev libgmp-dev unzip supervisor; \
    curl -fsSL -o /tmp/phpredis.tar.gz "https://github.com/phpredis/phpredis/archive/refs/tags/${PHPREDIS_VERSION}.tar.gz"; \
    echo "${PHPREDIS_SHA256}  /tmp/phpredis.tar.gz" | sha256sum -c -; \
    docker-php-source extract; \
    mkdir -p /usr/src/php/ext/redis; \
    tar -xzf /tmp/phpredis.tar.gz --strip-components=1 -C /usr/src/php/ext/redis; \
    rm /tmp/phpredis.tar.gz; \
    docker-php-ext-install -j"$(nproc)" pdo_pgsql pgsql pcntl bcmath intl zip gmp opcache redis; \
    docker-php-source delete; \
    apt-get purge -y --auto-remove libicu-dev libzip-dev libgmp-dev; \
    apt-get install -y --no-install-recommends libicu76 libzip5 libgmp10; \
    rm -rf /var/lib/apt/lists/*; \
    a2dismod -f mpm_event mpm_worker || true; \
    a2enmod mpm_prefork rewrite headers remoteip; \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

COPY --from=composer /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Release source, checked against its sha256.
RUN set -eux; \
    rm -rf /var/www/html/*; \
    curl -fsSL -o /tmp/sp.tar.gz "https://github.com/mettle/sendportal/archive/refs/tags/v${SENDPORTAL_VERSION}.tar.gz"; \
    echo "${SENDPORTAL_SHA256}  /tmp/sp.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/sp.tar.gz --strip-components=1 -C /var/www/html; \
    rm /tmp/sp.tar.gz

# Upstream commits no composer.lock; this one pins every PHP dependency.
COPY composer.lock /var/www/html/composer.lock

RUN set -eux; \
    COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader --no-progress; \
    rm -rf /root/.composer/cache; \
    # Railway's edge is the only peer and overwrites X-Forwarded-*: trust it so
    # Laravel sees https and builds https URLs.
    sed -i 's#protected \$proxies;#protected $proxies = "*";#' app/Http/Middleware/TrustProxies.php; \
    grep -q 'protected $proxies = "\*";' app/Http/Middleware/TrustProxies.php; \
    php artisan vendor:publish --provider='Sendportal\Base\SendportalBaseServiceProvider' --tag=sendportal-assets --force; \
    touch .env; \
    chown -R www-data:www-data storage bootstrap/cache

COPY railway/apache.conf /etc/apache2/sites-available/000-default.conf
COPY railway/ports.conf /etc/apache2/ports.conf
COPY railway/php.ini $PHP_INI_DIR/conf.d/zz-sendportal.ini
COPY railway/supervisord.conf /etc/supervisor/conf.d/sendportal.conf
COPY railway/create-admin.php /opt/sendportal/create-admin.php
COPY railway/start.sh /usr/local/bin/sendportal-start
COPY railway/fatal-listener.sh /usr/local/bin/sendportal-fatal-listener
RUN chmod +x /usr/local/bin/sendportal-start /usr/local/bin/sendportal-fatal-listener

ENV PORT=8080
EXPOSE 8080
CMD ["sendportal-start"]
