FROM php:8.3-fpm

# Allow Composer to run as root
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install system dependencies + Nginx
RUN apt-get update && apt-get install -y \
    git \
    curl \
    nginx \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install pdo pdo_mysql mbstring exif pcntl bcmath gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy composer files first (layer caching)
COPY composer.json composer.lock ./

# Install dependencies (no dev, optimized autoloader)
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction

# Copy the rest of the application
COPY . .

# Wipe any stale cache so entrypoint always builds fresh at runtime
RUN rm -rf var/cache/*

# Run post-install scripts now that full app is present
RUN composer run-script post-install-cmd --no-interaction || true

# Ensure var/ subdirectories exist
RUN mkdir -p var/cache var/log

# Copy Nginx config
COPY nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# Copy and set entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Set correct permissions for Symfony var/ directory
RUN chown -R www-data:www-data /var/www/html/var \
    && chmod -R 775 /var/www/html/var

EXPOSE 80

ENTRYPOINT ["entrypoint.sh"]