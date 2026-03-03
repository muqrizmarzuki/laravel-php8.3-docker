FROM php:8.3-fpm

# Install System Dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    libpng-dev \
    libzip-dev \
    zip \
    unzip \
    git \
    libpq-dev \
    curl \
    gnupg \
    vim

# Install Node.js (NodeSource)
RUN mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install nodejs -y

# Install PHP Extensions
RUN docker-php-ext-install -j$(nproc) pdo_mysql bcmath zip pcntl posix sockets
RUN pecl install redis && docker-php-ext-enable redis

# Configure Nginx and Supervisor
RUN mkdir -p /var/log/supervisor /run/nginx
COPY docker/conf.d/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

COPY docker/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set Working Directory
WORKDIR /var/www

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

EXPOSE 80
