#!/bin/sh
set -e
printenv > /etc/environment
if [ -f /var/www/html/step-cron ]; then
  cp /var/www/html/step-cron /etc/cron.d/step-cron
  chmod 0644 /etc/cron.d/step-cron
  crontab /etc/cron.d/step-cron 2>/dev/null || true
fi
cron
apache2-foreground
