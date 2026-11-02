#!/bin/sh

# Stop the script (and so the container, which Docker then restarts) as soon as a
# command fails: a half-done setup must never end in a running php-fpm
set -e

# ANSI escape codes for terminal messages
RED='\033[0;31m'
GRAY='\033[0;90m'
GREEN='\033[0;32m'
RESETCOLOR='\033[0m'

# Check if mandatory environment variables are set
if [ -z "${DOMAIN_NAME}" ] || [ -z "${SQL_DATABASE}" ] || [ -z "${SQL_USER}" ] || [ -z "${SQL_PASSWORD}" ] || [ -z "${WP_ADMIN_USER}" ] || [ -z "${WP_ADMIN_PASSWORD}" ] || [ -z "${WP_ADMIN_EMAIL}" ] || [ -z "${WP_USER}" ] || [ -z "${WP_USER_PASSWORD}" ] || [ -z "${WP_USER_EMAIL}" ]; then
	printf '%b\n' "${RED}Inception: WordPress environment variables are missing! Exiting.${RESETCOLOR}" >&2
	exit 1
fi

# 1. Wait for MariaDB to start and accept connections
# The container won't proceed until the WordPress user can really log in to the
# database. "mariadb-admin ping" is not enough: it succeeds even when the login
# is refused (e.g. the user has not been created yet during the first boot).
# The wait is limited: after 60 attempts (about 2 minutes) the container exits and Docker restarts it.
printf '%b\n' "${GRAY}Inception: Waiting for MariaDB database to be ready...${RESETCOLOR}"
tries=0
until mariadb -h mariadb -u"${SQL_USER}" -p"${SQL_PASSWORD}" "${SQL_DATABASE}" -e "SELECT 1;" > /dev/null 2>&1; do
	tries=$((tries + 1))
	if [ "${tries}" -ge 60 ]; then
		printf '%b\n' "${RED}Inception: MariaDB is not reachable after 60 attempts. Exiting.${RESETCOLOR}" >&2
		exit 1
	fi
	sleep 2
done
printf '%b\n' "${GREEN}Inception: MariaDB is ready.${RESETCOLOR}"

# Move to the web root folder shared with NGINX via volume
cd /var/www/html

# 2. Download WordPress and generate wp-config.php if not present yet
if [ ! -f "wp-config.php" ]; then
	printf '%b\n' "${GRAY}Inception: Downloading WordPress core files via WP-CLI...${RESETCOLOR}"

	# Download latest WordPress core files into current directory
	wp core download --allow-root
	printf '%b\n' "${GRAY}Inception: Generating wp-config.php file...${RESETCOLOR}"

	# Create wp-config.php with database credentials
	# Note: dbhost MUST be set to 'mariadb:3306' (the container name in docker-compose network)
	wp config create \
		--allow-root \
		--dbname="${SQL_DATABASE}" \
		--dbuser="${SQL_USER}" \
		--dbpass="${SQL_PASSWORD}" \
		--dbhost="mariadb:3306"
fi

# 3. Install WordPress if the database does not contain the site yet.
# This is checked on the database (not on wp-config.php), so an interrupted
# first start is completed at the next start instead of staying broken.
if ! wp core is-installed --allow-root; then
	printf '%b\n' "${GRAY}Inception: Installing WordPress and setting up admin account...${RESETCOLOR}"

	# Install WordPress core: sets site URL, title, and creates the Admin user
	wp core install \
		--allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${SITE_TITLE:-Inception}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin_password="${WP_ADMIN_PASSWORD}" \
		--admin_email="${WP_ADMIN_EMAIL}" \
		--skip-email

	wp user create \
		"${WP_USER}" \
		"${WP_USER_EMAIL}" \
		--role=author \
		--user_pass="${WP_USER_PASSWORD}" \
		--allow-root

	printf '%b\n' "${GREEN}Inception: WordPress installed successfully.${RESETCOLOR}"
fi

# WP-CLI runs as root: give the files to www-data (user of the PHP-FPM workers),
# otherwise WordPress cannot upload media or install plugins/themes
chown -R www-data:www-data /var/www/html

# exec replaces the shell process with php-fpm (-F = foreground), making it PID 1
exec php-fpm8.2 -F