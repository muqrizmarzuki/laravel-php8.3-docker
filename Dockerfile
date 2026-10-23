ARG PHP_VERSION=8.3.36
FROM php:${PHP_VERSION}-fpm-trixie

# Browsershot uses system Chromium, so stop puppeteer downloading its own copy on npm install
ENV PUPPETEER_SKIP_DOWNLOAD=true

# Install Runtime Dependencies (nginx, supervisor, Chromium for Spatie Laravel PDF / Browsershot)
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    supervisor \
    zip \
    unzip \
    curl \
    ca-certificates \
    chromium \
    fonts-liberation \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (copied from the official image, needed by Browsershot and vite)
COPY --from=node:22-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:22-slim /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Install Python + pdfplumber for PDF SLT extraction (pip removed afterwards)
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip \
    && pip3 install --no-cache-dir --break-system-packages pdfplumber \
    && apt-get purge -y --auto-remove python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install PHP Extensions, then purge the -dev build packages and keep only the runtime libs
RUN savedAptMark="$(apt-mark showmanual)" \
    && apt-get update && apt-get install -y --no-install-recommends \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libwebp-dev \
        libzip-dev \
    && docker-php-ext-configure gd --with-jpeg --with-freetype --with-webp \
    && docker-php-ext-install -j$(nproc) pdo_mysql bcmath zip pcntl gd exif opcache \
    && pecl install redis \
    && docker-php-ext-enable redis \
    && rm -rf /tmp/pear \
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedAptMark \
    && find /usr/local/bin /usr/local/sbin /usr/local/lib/php/extensions -type f -executable -exec ldd '{}' ';' 2>/dev/null \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) { next }; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
        | sort -u > /tmp/runtime-libs.txt \
    && cat /tmp/runtime-libs.txt \
    && xargs -r dpkg-query --search < /tmp/runtime-libs.txt | grep -v '^diversion' | cut -d: -f1 | sort -u | xargs -r apt-mark manual \
    && rm /tmp/runtime-libs.txt \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/*

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

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

EXPOSE 80
