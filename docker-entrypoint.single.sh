#!/bin/sh
set -e

DB_NAME="${DB_NAME:-step_system}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-${MYSQL_ROOT_PASSWORD:-}}"
APP_DEBUG="${APP_DEBUG:-0}"
INSTALL_TOKEN="${INSTALL_TOKEN:-change-me-install-token}"

mkdir -p /run/mysqld /var/lib/mysql /var/www/html/storage /var/www/html/config
chown -R mysql:mysql /run/mysqld /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
  echo "[single] initializing MariaDB data directory"
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
fi

echo "[single] starting MariaDB"
mysqld_safe --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --bind-address=127.0.0.1 >/var/www/html/storage/mysql.log 2>&1 &

for i in $(seq 1 60); do
  if mysqladmin ping --socket=/run/mysqld/mysqld.sock --silent >/dev/null 2>&1; then
    break
  fi
  sleep 1
  if [ "$i" = "60" ]; then
    echo "[single] MariaDB failed to start" >&2
    tail -80 /var/www/html/storage/mysql.log >&2 || true
    exit 1
  fi
done

mysql --socket=/run/mysqld/mysqld.sock -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_PASS}';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
ALTER USER 'root'@'127.0.0.1' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

cat > /var/www/html/config/database.php <<PHP
<?php
return array (
  'host' => '127.0.0.1',
  'name' => '${DB_NAME}',
  'user' => 'root',
  'pass' => '${DB_PASS}',
);
PHP
chmod 640 /var/www/html/config/database.php || true

printenv > /etc/environment
if [ -f /var/www/html/step-cron ]; then
  cp /var/www/html/step-cron /etc/cron.d/step-cron
  chmod 0644 /etc/cron.d/step-cron
  crontab /etc/cron.d/step-cron 2>/dev/null || true
fi
cron

export DB_HOST=127.0.0.1
export DB_NAME DB_USER DB_PASS APP_DEBUG INSTALL_TOKEN
exec apache2-foreground
