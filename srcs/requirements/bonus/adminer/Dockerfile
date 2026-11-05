# To implement Adminer cleanly and consistently with my architecture, I configured
# it via PHP-FPM just like with WordPress. This way, we avoid routing or HTTP
# route issues and keep NGINX as the only true web server in my infrastructure.

FROM debian:bookworm

# Install PHP-FPM, the MySQL extension for PHP, and wget for downloading Adminer
# Note: php-session is included to ensure session handling works correctly
RUN apt-get update && apt-get install -y \
	php-fpm \
	php-mysql \
	wget \
	&& rm -rf /var/lib/apt/lists/*

# Create the necessary directories for Adminer and PHP files
RUN mkdir -p /var/www/adminer \
	&& mkdir -p /run/php
WORKDIR /var/www/adminer

# Download Adminer and place it in the right directory
RUN wget -O adminer.php https://www.adminer.org/latest.php

# Set the ownership of the Adminer directory to the www-data user and group
RUN chown -R www-data:www-data /var/www/adminer

# Di default su Debian, PHP-FPM ascolta su un socket Unix. 
# Lo cambiamo per farlo esporre sulla porta 9000, in modo che NGINX possa comunicare.
RUN sed -i 's|listen = /run/php/php8.2-fpm.sock|listen = 9000|' /etc/php/8.2/fpm/pool.d/www.conf

EXPOSE 9000

# Set the entrypoint to the PHP command, which will start the PHP FastCGI Process
# Manager in foreground
CMD ["/usr/sbin/php-fpm8.2", "-F"]
