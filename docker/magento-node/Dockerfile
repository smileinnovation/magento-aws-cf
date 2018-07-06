FROM php:7.1-fpm

ENV CONFD_VERSION 0.16.0
ENV NGINX_VERSION 1.15.0-1~stretch

# Set default parameters
ENV FQDN="localhost" USE_SSL="false" UNATTENDED="false" DEBUG="false" UPDATE_UID_GID="false" PHP_MEMORY_LIMIT="2G" PHP_ENABLE_XDEBUG="false" MAGENTO_ROOT="/var/www/magento" MAGENTO_RUN_MODE="developer" UPLOAD_MAX_FILESIZE="64M" \
    MYSQL_HOSTNAME="mysql" MYSQL_USERNAME="root" MYSQL_PASSWORD="secure" MYSQL_DATABASE="magento" CRYPT_KEY="" \
    USE_REDIS="false" REDIS_SERVER="localhost" REDIS_PORT="6379" REDIS_SESSION_DB="0" REDIS_CACHE_BACKEND_DB="1" REDIS_PAGE_CACHE_DB="2" \
    ADMIN_USERNAME="admin" ADMIN_PASSWORD="adm1nistrator" ADMIN_FIRSTNAME="admin" \
    ADMIN_LASTNAME="admin" ADMIN_EMAIL="admin@localhost.com" CURRENCY="EUR" LANGUAGE="en_US" \
    TIMEZONE="Europe/Paris" BACKEND_FRONTNAME="admin" CONTENT_LANGUAGES="en_US" ES_HOST="elasticsearch:9200" ES_USER="elastic" ES_PASSWORD="changeme" ES_ENABLE_SSL="false"

ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.1.5/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=9aeb41e00cc7b71d30d33c57a2333f2c2581a201

# Install Magento 2 dependencies and supervisor
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
        gnupg2 dirmngr wget apt-transport-https lsb-release ca-certificates \
        cron \
        wget \
        git \
        python-pip \
        python-setuptools \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libxml2-dev \
        libxslt1-dev \
        libicu-dev \
        mysql-client \
        sendmail-bin \
        sendmail \
        xmlstarlet \
        && pip install wheel \
        && pip install supervisor supervisor-stdout \
        && echo "#!/bin/sh\nexit 0" > /usr/sbin/policy-rc.d \
        && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install nginx
RUN wget http://nginx.org/keys/nginx_signing.key \
    && apt-key add nginx_signing.key \
    && rm nginx_signing.key \
    && echo "deb http://nginx.org/packages/mainline/debian/ stretch nginx" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y nginx=${NGINX_VERSION} \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN docker-php-ext-install -j$(nproc) iconv mcrypt \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-install -j$(nproc) bcmath \
    && docker-php-ext-install dom \
    && docker-php-ext-install intl \
    && docker-php-ext-install json \
    && docker-php-ext-install iconv \
    && docker-php-ext-install mcrypt \
    && docker-php-ext-install mbstring \
    && docker-php-ext-install opcache \
    && docker-php-ext-install pcntl \
    && docker-php-ext-install pdo \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install soap \
    && docker-php-ext-install xsl \
    && docker-php-ext-install zip \
    && pecl install redis-3.1.6 \
    && pecl install -o -f xdebug \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/* /var/tmp/*

RUN curl -fsSLO "$SUPERCRONIC_URL" \
 && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
 && chmod +x "$SUPERCRONIC" \
 && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
 && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic

# Create magento user
RUN useradd -m -d /home/magento -u 1001 magento && usermod -a -G root magento

# Install confd
RUN wget https://github.com/kelseyhightower/confd/releases/download/v$CONFD_VERSION/confd-$CONFD_VERSION-linux-amd64 \
    && cp confd-$CONFD_VERSION-linux-amd64 /usr/local/bin/confd \
    && chmod ugo+x /usr/local/bin/confd \
    && rm confd-$CONFD_VERSION-linux-amd64

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
    && php composer-setup.php --install-dir=/usr/local/bin/ --filename=composer \
    && php -r "unlink('composer-setup.php');"

RUN mkdir -p /etc/confd && chmod go+rx /etc/confd

# Supervisor config
COPY ./supervisor/supervisord.conf /etc/supervisord.conf

# Copy base nginx config
COPY ./nginx/nginx.conf /etc/nginx/

# Copy confd templates
COPY ./confd /etc/confd

RUN mkdir -p /usr/local/etc/php/conf.d \
  && chgrp 0 /usr/local/etc/php/conf.d \
  && chmod g+rw /usr/local/etc/php/conf.d \
  && chgrp 0 /usr/local/etc \
  && chmod g+rw /usr/local/etc

RUN mkdir -p $MAGENTO_ROOT \
  && chown magento $MAGENTO_ROOT \
  && chgrp 0 $MAGENTO_ROOT \
  && chmod g+rw $MAGENTO_ROOT \
  && chgrp 0 /etc/nginx/conf.d && chmod g+rw /etc/nginx/conf.d \
  && chgrp 0 /run && chmod g+rw /run \
  && chgrp -R 0 /home/magento && chmod g+rw /home/magento

RUN mkdir -p /etc/cron.d/magento \
  && chown magento /etc/cron.d/magento \
  && chgrp 0 /etc/cron.d/magento \
  && chmod g+rw /etc/cron.d/magento

RUN mkdir -p /home/magento/crontab && touch /home/magento/crontab/magento

RUN ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && rm -f /var/run/nginx.pid && rm -f /etc/nginx/conf.d/default.conf

# Hack to allow the overriding of local user id at runtime
RUN chmod -R g+rw /etc/passwd && chmod -R g+rw /etc/group

COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Copy magento app
COPY --chown=magento:root src $MAGENTO_ROOT

# Copy hooks
COPY --chown=magento:root hooks /home/magento/hooks/

VOLUME $MAGENTO_ROOT

WORKDIR $MAGENTO_ROOT

EXPOSE 80

USER magento

ENTRYPOINT [ "/usr/local/bin/entrypoint.sh" ]
