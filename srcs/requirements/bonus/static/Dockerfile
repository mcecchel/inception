FROM debian:bookworm

# Install NGINX only: the website is made of static files, no PHP or other runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
	nginx \
	&& rm -rf /var/lib/apt/lists/*

# Copy the NGINX configuration file from the host into the image
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Copy the website (html, css, js, font) into the web root
COPY . /var/www/static
# Make sure the NGINX workers (unprivileged) can read every file whatever the host permissions are
RUN chmod -R a+rX /var/www/static

# Internal port of the static website (not published on the host)
EXPOSE 8080

# NGINX is the only process and runs in foreground (daemon off), so it is PID 1
# and receives SIGTERM directly: no entrypoint script is needed here
CMD ["nginx", "-g", "daemon off;"]