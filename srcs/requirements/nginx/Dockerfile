# Choosing Debian as base (second-last stable version)
FROM debian:bookworm

# Update packages and install NGINX and OpenSSL
#	apt-get update: Download the updated list of packages (Debian image starts with an empty list)
#	apt-get install -y <packages> for installation.
#	Flag -y responds “yes” automatically 'cause no one can type during the build
#	Flag --no-install-recommends avoids installing unnecessary packages (like documentation, etc)
#	rm -rf /var/lib/apt/lists/ to clean up cache and reduce image size
RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	openssl \
	&& rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script from the host into the image
COPY ./tools/nginx_entrypoint.sh /usr/local/bin/nginx_entrypoint.sh

# Copy the NGINX configuration file from the host into the image
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/nginx_entrypoint.sh

# Exposing (as mandatory) ports for HTTPS traffic
EXPOSE 443

# Set the entrypoint to the script that will handle SSL certificate generation and NGINX startup
ENTRYPOINT ["/usr/local/bin/nginx_entrypoint.sh"]