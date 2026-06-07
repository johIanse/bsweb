FROM php:8.2-apache

RUN apt-get update \
    && apt-get install -y libcurl4-openssl-dev cron nodejs npm \
    && docker-php-ext-install pdo_mysql curl \
    && mkdir -p /opt \
    && npm install --prefix /opt got@11 tough-cookie iconv-lite global-agent hpagent \
    && test -f /opt/node_modules/tough-cookie/package.json \
    && test -f /opt/node_modules/got/package.json \
    && test -f /opt/node_modules/iconv-lite/package.json \
    && test -f /opt/node_modules/global-agent/package.json \
    && test -f /opt/node_modules/hpagent/package.json \
    && a2enmod rewrite \
    && rm -rf /var/lib/apt/lists/*

ENV NODE_PATH=/opt/node_modules
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf
COPY step-cron /etc/cron.d/step-cron
RUN chmod 0644 /etc/cron.d/step-cron
COPY docker-entrypoint.sh /usr/local/bin/step-entrypoint.sh
RUN chmod +x /usr/local/bin/step-entrypoint.sh
WORKDIR /var/www/html
CMD ["step-entrypoint.sh"]