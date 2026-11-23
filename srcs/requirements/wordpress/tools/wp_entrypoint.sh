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

# 1. MariaDB readiness is guaranteed by the healthcheck + depends_on in docker-compose.yml.
# If the DB is still unreachable, the WP-CLI commands below fail, set -e stops the
# script and Docker restarts the container.

# Move to the web root folder shared with NGINX via volume
cd /var/www/html

# 2. Download WordPress and generate wp-config.php if not present yet
if [ ! -f "wp-config.php" ]; then
	printf '%b\n' "${GRAY}Inception: Downloading WordPress core files via WP-CLI...${RESETCOLOR}"

	# Download latest WordPress core files into current directory
	wp core download --allow-root
	printf '%b\n' "${GRAY}Inception: Generating wp-config.php file...${RESETCOLOR}"

	# Create wp-config.php with database credentials
	# Note: dbhost MUST use the container name in the docker-compose network (mariadb)
	# followed by the MariaDB port (SQL_PORT in .env, 3306 if unset)
	wp config create \
		--allow-root \
		--dbname="${SQL_DATABASE}" \
		--dbuser="${SQL_USER}" \
		--dbpass="${SQL_PASSWORD}" \
		--dbhost="mariadb:${SQL_PORT:-3306}"
fi

# wp-config.php lives in the wp_data volume, so it survives rebuilds and is NOT
# regenerated above. Keep DB_HOST aligned with SQL_PORT at every start: otherwise
# changing the MariaDB port would leave the old port in the persisted file.
wp config set DB_HOST "mariadb:${SQL_PORT:-3306}" --allow-root

# The site URL must follow the address (and port) the browser really uses, otherwise
# changing the NGINX port would leave links, CSS and redirects pointing to the old one.
# WP_HOME / WP_SITEURL are therefore computed by PHP from the Host header:
#\t- the Host is accepted only if it is DOMAIN_NAME, optionally followed by :port
#\t  (preg_quote escapes the dots), so a forged Host header cannot change the URL
#\t- otherwise (and in WP-CLI, which has no web request) it falls back to DOMAIN_NAME
# --raw writes the value as PHP code instead of a quoted string; it is rewritten at
# every start, so a change of DOMAIN_NAME in .env is applied to the persisted file.
WP_URL_EXPR="(isset(\$_SERVER['HTTP_HOST']) && preg_match('/^' . preg_quote('${DOMAIN_NAME}', '/') . '(:[0-9]+)?\$/', \$_SERVER['HTTP_HOST'])) ? 'https://' . \$_SERVER['HTTP_HOST'] : 'https://${DOMAIN_NAME}'"
wp config delete WP_HOME WP_SITEURL --allow-root 2>/dev/null || true
wp config set WP_HOME "${WP_URL_EXPR}" --raw --type=constant --anchor="/* That's all, stop editing!" --allow-root
wp config set WP_SITEURL "${WP_URL_EXPR}" --raw --type=constant --anchor="/* That's all, stop editing!" --allow-root

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