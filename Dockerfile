FROM php:8.3-fpm

# Install System Dependencies
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    libpng-dev \
    libjpeg62-turbo-dev \
    libfreetype6-dev \
    libwebp-dev \
    libmagickwand-dev \
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
RUN docker-php-ext-configure gd --with-jpeg --with-freetype --with-webp
RUN docker-php-ext-install -j$(nproc) pdo_mysql bcmath zip pcntl posix sockets gd exif
RUN pecl install redis imagick \
    && docker-php-ext-enable redis imagick

    # Install Python + pdfplumber for PDF SLT extraction
RUN apt-get install -y --no-install-recommends python3 python3-pip \
    && pip3 install pdfplumber --break-system-packages \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Chromium + Puppeteer for Spatie Laravel PDF (Browsershot)
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-liberation \
    libatk-bridge2.0-0 \
    libgtk-3-0 \
    libnss3 \
    libxss1 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# PHP Upload Limits
RUN echo "upload_max_filesize=100M" > /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "post_max_size=100M" >> /usr/local/etc/php/conf.d/z-uploads.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/z-uploads.ini

# Configure Nginx and Supervisor
RUN mkdir -p /var/log/supervisor /run/nginx
COPY docker/conf.d/nginx.conf /etc/nginx/sites-available/default
RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

COPY docker/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set Working Directory
WORKDIR /var/www

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

EXPOSE 80
