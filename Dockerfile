FROM php:8.1-fpm-alpine3.14

RUN apk update && apk add --no-cache \
    bash \
    curl \
    zip \
    unzip \
    nginx \
    supervisor \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libwebp-dev \
    libxml2-dev \
    oniguruma-dev \
    libzip-dev \
    nodejs \
    npm \
    fontconfig \
    ttf-freefont \
    libx11 \
    libxext \
    libxrender \
    freetype \
    libjpeg-turbo \
    wkhtmltopdf \
    && ln -s /usr/bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf

# Configure GD and install PHP extensions
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg \
        --with-webp \
    && docker-php-ext-install -j$(nproc) gd exif pdo pdo_mysql zip

# Configure Nginx and Supervisor
RUN mkdir -p /var/log/supervisor /run/nginx
COPY docker/conf.d/nginx.conf /etc/nginx/http.d/default.conf

COPY docker/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set Working Directory
WORKDIR /var/www

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# PHP Upload Limits
RUN echo "upload_max_filesize=100M" > /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "post_max_size=100M" >> /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/z-uploads.ini

EXPOSE 80
