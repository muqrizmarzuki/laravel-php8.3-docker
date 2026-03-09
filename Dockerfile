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

# Install wkhtmltopdf + GD dependencies in one layer
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        libfontconfig1 \
        libxrender1 \
        xfonts-75dpi \
        xfonts-base \
        xz-utils \
        libxext6 \
        libx11-6 \
        libwebp-dev \
        libjpeg-dev \
        libpng-dev \
        libfreetype6-dev \
    ; \
    \
    # Temporary Bullseye repo for libssl1.1
    echo "deb http://deb.debian.org/debian bullseye main" > /etc/apt/sources.list.d/bullseye.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends libssl1.1; \
    rm /etc/apt/sources.list.d/bullseye.list; \
    \
    # Install wkhtmltopdf
    wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb; \
    dpkg -i wkhtmltox_0.12.6-1.buster_amd64.deb || apt-get install -f -y; \
    rm wkhtmltox_0.12.6-1.buster_amd64.deb; \
    \
    # Install PHP extensions
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j$(nproc) gd exif; \
    \
    # Cleanup
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# PHP Upload Limits
RUN echo "upload_max_filesize=100M" > /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "post_max_size=100M" >> /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/z-uploads.ini

# NGINX Upload Limits
RUN mkdir -p /etc/nginx/conf.d \
    && echo "client_max_body_size 100M;" > /etc/nginx/conf.d/limits.conf

EXPOSE 80
