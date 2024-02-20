FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

# UPDATE PACKAGES
RUN apt-get update

# SYSTEM UTILITIES
RUN apt-get install -y \
    apt-utils \
    curl \
    git \
    apt-transport-https \
    software-properties-common \
    g++ \
    build-essential \
    lsb-release \
    gnupg2 \
    ca-certificates \
    zip \
    unzip

# APACHE2
RUN apt-get install -y apache2
RUN a2enmod rewrite
RUN a2enmod lbmethod_byrequests

# PHP & LIB
RUN add-apt-repository -y ppa:ondrej/php \
    && apt-get update \
    && apt-get --no-install-recommends --no-install-suggests --yes --quiet install \
    php-pear \
    php8.2 \
    php8.2-fpm \
    php8.2-common \
    php8.2-mbstring \
    php8.2-dev \
    php8.2-xml \
    php8.2-cli \
    php8.2-curl \
    php8.2-gd \
    php8.2-imagick \
    php8.2-xdebug \
    php8.2-zip \
    php8.2-odbc \
    php8.2-opcache \
    php8.2-redis \
    autoconf \
    zlib1g-dev \
    libapache2-mod-php8.2 \
    && apt-get remove libapache2-mod-php5
RUN a2enmod php8.2
    # a2dismod mpm_prefork \
    # a2dismod mpm_worker \
    # a2dismod mpm_event

# ODBC DRIVER & TOOLS
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - \
    && curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y \
    msodbcsql18 \
    mssql-tools18 \
    unixodbc \
    unixodbc-dev

RUN echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc && exec bash

# SQL SERVER & PDO
RUN pecl install sqlsrv \
    && echo 'extension=sqlsrv.so' > /etc/php/8.2/cli/conf.d/20-sqlsrv.ini \
    && echo 'extension=sqlsrv.so' > /etc/php/8.2/apache2/conf.d/20-sqlsrv.ini
RUN pecl install pdo_sqlsrv \
    && echo 'extension=pdo_sqlsrv.so' > /etc/php/8.2/cli/conf.d/30-pdo_sqlsrv.ini \
    && echo 'extension=pdo_sqlsrv.so' > /etc/php/8.2/apache2/conf.d/30-pdo_sqlsrv.ini

# RUN echo 'ServerName localhost' > /etc/apache2/apache2.conf
# RUN echo 'LoadModule mpm_event_module modules/mod_mpm_event.so' > /etc/apache2/apache2.conf

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Node & NPM
ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=21.5.0
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
SHELL ["/bin/bash", "-c"]
RUN source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm alias default $NODE_VERSION && npm install -g npm@10.2.5

# Project Directory
WORKDIR /var/www/html

# Copy Laravel project files into the container
COPY . /var/www/html

# Set the appropriate permissions for Laravel
RUN chmod -R 755 /var/www/html
RUN chown -R www-data:www-data /var/www/html  

# Set the DocumentRoot to the public directory
RUN sed -i -e 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|' /etc/apache2/sites-available/000-default.conf

# Set Apache2 Directory Access after DocumentRoot
RUN sed -i '/\/var\/www\/html\/public/a\
    <Directory "/var/www/html/public">\n \
        AllowOverride All\n \
        Options FollowSymLinks Indexes\n \
        Order allow,deny\n \
        Allow from all\n \
	</Directory>' /etc/apache2/sites-available/000-default.conf

# Install Composer
RUN composer install

CMD [ "/usr/sbin/apache2ctl", "-D", "FOREGROUND" ]