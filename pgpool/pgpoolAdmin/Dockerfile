FROM php:8.1-apache

# Install required PHP extensions and tools
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    libpq-dev \
    libssl-dev \
    libpng-dev \
    libzip-dev \
    libxml2-dev \
    && docker-php-ext-install pgsql mysqli pdo pdo_pgsql zip xml gd

# Set working directory
WORKDIR /var/www/html

# Download and extract pgpoolAdmin
RUN wget ftp://www.pgpool.net/pub/pgpoolAdmin/pgpoolAdmin-4.2.3.tar.gz -O pgpoolAdmin.tar.gz && \
    tar -xvzf pgpoolAdmin.tar.gz && \
    mv pgpoolAdmin-4.2.3 pgpoolAdmin && \
    rm pgpoolAdmin.tar.gz

# Configure permissions
RUN chown -R www-data:www-data /var/www/html/pgpoolAdmin && \
    chmod -R 755 /var/www/html/pgpoolAdmin

# Expose Apache port
EXPOSE 80
