#!/bin/sh

DB_HOST="${MYSQL_HOST:-${MYSQLHOST:-platform_docker-db}}"
DB_NAME="${MYSQL_DATABASE:-${MYSQLDATABASE:-database_platform}}"
DB_USER="${MYSQL_USER:-${MYSQLUSER:-user_platform}}"
DB_PASS="${MYSQL_PASSWORD:-${MYSQLPASSWORD:-password_platform}}"

echo "==> Waiting for database to be ready at ${DB_HOST}..."
until php -r "new PDO('mysql:host=${DB_HOST};dbname=${DB_NAME}', '${DB_USER}', '${DB_PASS}');" 2>/dev/null; do
echo "    Database not ready yet, retrying in 3s..."
sleep 3
done
echo "==> Database is ready."

echo "==> Running database migrations..."
php bin/console doctrine:migrations:migrate --no-interaction --allow-no-migration || echo "    Migrations warning (continuing...)"

echo "==> Clearing stale cache..."
rm -rf var/cache/prod

echo "==> Clearing cache..."
php bin/console cache:clear --env=prod --no-debug || echo "    Cache clear warning (continuing...)"

echo "==> Warming up cache..."
php bin/console cache:warmup --env=prod --no-debug || echo "    Cache warmup warning (continuing...)"

echo "==> Setting permissions..."
chown -R www-data:www-data /var/www/html/var 2>/dev/null || true
chmod -R 775 /var/www/html/var 2>/dev/null || true

echo "==> Starting PHP-FPM..."
php-fpm -D

echo "==> Starting Nginx..."
exec nginx -g "daemon off;"