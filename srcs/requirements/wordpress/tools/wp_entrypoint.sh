#!/bin/sh

# ANSI escape codes for terminal messages
RED='\033[0;31m'
GRAY='\033[0;90m'
GREEN='\033[0;32m'
RESETCOLOR='\033[0m'

# Check if mandatory environment variables are set
if [ -z "${DOMAIN_NAME}" ] \vert{}\vert{} [ -z "${SQL_DATABASE}" ] || [ -z "${SQL_USER}" ] \vert{}\vert{} [ -z "${SQL_PASSWORD}" ] || [ -z "${WP_ADMIN_USER}" ] \vert{}\vert{} [ -z "${WP_ADMIN_PASSWORD}" ] || [ -z "${WP_ADMIN_EMAIL}" ] \vert{}\vert{} [ -z "${WP_USER}" ] || [ -z "${WP_USER_PASSWORD}" ] \vert{}\vert{} [ -z "${WP_USER_EMAIL}" ]; then
	printf '%b\n' "${RED}Inception: WordPress environment variables are missing! Exiting.${RESETCOLOR}" >&2
	exit 1
fi

# 1. Wait for MariaDB to start and accept connections
# The container won't proceed until MariaDB responds to ping
printf '%b\n' "${GRAY}Inception: Waiting for MariaDB database to be ready...${RESETCOLOR}"
while ! mariadb-admin ping -h mariadb -u"${SQL_USER}" -p"${SQL_PASSWORD}" --silent; do
	sleep 2
done
printf '%b\n' "${GREEN}Inception: MariaDB is ready.${RESETCOLOR}"

# Move to the web root folder shared with NGINX via volume
cd /var/www/html

# 2. Check if WordPress is already installed
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

	printf '%b\n' "${GRAY}Inception: Installing WordPress and setting up admin account...${RESETCOLOR}"

	# Install WordPress core: sets site URL, title, and creates the Admin user
	wp core install \
		--allow-root \
		--url="https://${DOMAIN_NAME}" \
		--title="${SITE_TITLE:-Inception}" \
		--admin_user="${WP_ADMIN_USER}" \
		--admin