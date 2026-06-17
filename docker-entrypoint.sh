#!/bin/sh
set -e

mkdir -p /var/www/html/storage /var/www/html/config
chmod 755 /var/www/html /var/www/html/config 2>/dev/null || true
chmod 775 /var/www/html/storage 2>/dev/null || true
if id www-data >/dev/null 2>&1; then
  chown -R www-data:www-data /var/www/html/storage 2>/dev/null || true
fi
[ -f /var/www/html/config/database.php ] && chmod 644 /var/www/html/config/database.php 2>/dev/null || true

printenv > /etc/environment
if [ -f /var/www/html/step-cron ]; then
  cp /var/www/html/step-cron /etc/cron.d/step-cron
  chmod 0644 /etc/cron.d/step-cron
  crontab /etc/cron.d/step-cron 2>/dev/null || true
fi
cron
apache2-foreground
