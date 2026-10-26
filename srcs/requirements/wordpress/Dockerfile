FROM debian:bookworm

# Update packages and install PHP-FPM, PHP-MySQL, curl, and MariaDB client
RUN apt-get update && apt-get install -y --no-install-recommends \
	php-fpm \
	php-mysql \
	curl \
	mariadb-client \
	&& rm -rf /var/lib/apt/lists/*

# Using curl to download WP-CLI and move it to /usr/local/bin/wp
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
	&& chmod +x /usr/local/bin/wp

# Create the /run/php directory for PHP-FPM temporary files
RUN mkdir -p /run/php

# Copy the custom PHP-FPM configuration file from the host into the image
COPY ./conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf

# Copy the entrypoint script from the host into the image
COPY ./tools/wp_entrypoint.sh /usr/local/bin/wp_entrypoint.sh
# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/wp_entrypoint.sh

# Exposing port for PHP-FPM traffic
EXPOSE 9000

# Set the entrypoint to the script that will handle WordPress setup and PHP-FPM startup
ENTRYPOINT ["/usr/local/bin/wp_entrypoint.sh"]