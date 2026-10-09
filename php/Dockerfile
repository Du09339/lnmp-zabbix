FROM php:8.3-fpm-alpine
RUN set -eux; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql opcache; \
    pecl install redis-6.3.0; \
    docker-php-ext-enable redis; \
    apk del .build-deps; \
    rm -rf /tmp/pear ~/.pearrc
COPY opcache.ini /usr/local/etc/php/conf.d/opcache.ini
WORKDIR /var/www/html
