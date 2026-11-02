#!/bin/sh

set -eu

# ANSI escape codes for terminal messages
RED='\033[0;31m'
GRAY='\033[0;90m'
GREEN='\033[0;32m'
RESETCOLOR='\033[0m'

# Check if environment variables are set. If not, stop the container
if [ -z "${SQL_DATABASE}" ] || [ -z "${SQL_USER}" ] || [ -z "${SQL_PASSWORD}" ] || [ -z "${SQL_ROOT_PASSWORD}" ]; then
	printf '%b\n' "${RED}Inception: Database environment variables are missing! Exiting.${RESETCOLOR}" >&2
	exit 1
fi

# The socket directory must exist and belong to "mysql" (mysqld_safe used to create it,
# plain mysqld does not). The mounted volume comes from the host: "mysql" must own it
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# Security check: if the database folder doesn't exist, we need to initialize it
if [ ! -d "/var/lib/mysql/${SQL_DATABASE}" ]; then
	printf '%b\n' "${GRAY}Inception: Initializing MariaDB data directory...${RESETCOLOR}"

	# Initialize the MariaDB data directory and system tables
	# This is required because the mounted volume /var/lib/mysql is initially empty
	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--skip-name-resolve > /dev/null

	printf '%b\n' "${GRAY}Inception: Creating database and users...${RESETCOLOR}"

	# --bootstrap makes mysqld read the SQL commands from stdin, execute them and
	# exit. No server is started in background (no init.d, no socket to wait for,
	# no "sleep"), so nothing runs in background before the final exec.
	# In bootstrap mode the grant tables are not loaded: the first FLUSH PRIVILEGES
	# is required to make CREATE USER / GRANT / ALTER USER work.
	# The anonymous users created by mariadb-install-db (''@'localhost') are removed:
	# they would take precedence over '${SQL_USER}'@'%' and refuse its login from
	# inside the mariadb container (e.g. docker exec ... mariadb -u ${SQL_USER} -p).
	if ! mysqld --user=mysql --bootstrap <<-SQL
		FLUSH PRIVILEGES;
		CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'%';
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
		DELETE FROM mysql.global_priv WHERE User = '';
		FLUSH PRIVILEGES;
	SQL
	then
		printf '%b\n' "${RED}Inception: Database setup failed. Exiting.${RESETCOLOR}" >&2
		exit 1
	fi

	printf '%b\n' "${GREEN}Inception: Database setup completed successfully.${RESETCOLOR}"
else
	# If the folder already exists, it means the setup was already done in a previous run.
	printf '%b\n' "${GREEN}Inception: Database already initialized. Skipping setup.${RESETCOLOR}"
fi

printf '%b\n' "${GRAY}Inception: Starting MariaDB daemon in foreground...${RESETCOLOR}"

# Start the database in foreground
#	exec replaces the shell process with mysqld, making it PID 1.
#	mysqld handles SIGTERM itself, so "docker stop" shuts the database down cleanly.
exec mysqld --user=mysql

# Perché @'%' invece di @'localhost'?
# Nella riga della creazione dell'utente, SQL_USER@'%' permette all'utente di
# connettersi da qualsiasi indirizzo IP. Dato che WordPress e MariaDB sono in
# due container separati (e quindi hanno due IP diversi all'interno della rete Docker),
# se avessimo usato localhost WordPress sarebbe stato bloccato.

# Perché exec mysqld e non mysqld_safe?
# Con exec lo script viene sostituito da mysqld, che diventa PID 1 e riceve
# direttamente SIGTERM da "docker stop", chiudendosi in modo pulito.
# mysqld_safe invece è a sua volta uno script che ignora SIGTERM (trap '' 15):
# come PID 1 non si fermerebbe, Docker dovrebbe aspettare il timeout e poi
# "killarlo" con SIGKILL, rischiando di corrompere i dati.