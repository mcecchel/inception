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

# Security check: if the database folder doesn't exist, we need to initialize it
if [ ! -d "/var/lib/mysql/${SQL_DATABASE}" ]; then
	printf '%b\n' "${GRAY}Inception: Initializing MariaDB data directory...${RESETCOLOR}"

	# Initialize the MariaDB data directory and system tables
	# This is required because the mounted volume /var/lib/mysql is initially empty
	mariadb-install-db \
		--user=mysql \
		--datadir=/var/lib/mysql \
		--skip-name-resolve > /dev/null

	printf '%b\n' "${GRAY}Inception: Starting MariaDB in background for setup...${RESETCOLOR}"
	
	# Start the service in background to allow us to send SQL queries
	/etc/init.d/mariadb start

	# Wait until the local Unix socket accepts authenticated root connections
	until mariadb \
		--protocol=socket \
		--socket=/run/mysqld/mysqld.sock \
		-uroot \
		-e "SELECT 1;" > /dev/null 2>&1
	do
		sleep 1
	done

	printf '%b\n' "${GRAY}Inception: Creating database and users...${RESETCOLOR}"

	# Use the initialization socket explicitly so setup does not fall back to TCP.
	mariadb \
		--protocol=socket \
		--socket=/run/mysqld/mysqld.sock \
		-uroot <<-SQL
		CREATE DATABASE IF NOT EXISTS \`${SQL_DATABASE}\`;
		CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '${SQL_PASSWORD}';
		GRANT ALL PRIVILEGES ON \`${SQL_DATABASE}\`.* TO '${SQL_USER}'@'%';
		ALTER USER 'root'@'localhost' IDENTIFIED BY '${SQL_ROOT_PASSWORD}';
		FLUSH PRIVILEGES;
	SQL

	printf '%b\n' "${GRAY}Inception: Shutting down background MariaDB...${RESETCOLOR}"
	
	# Stop the background service properly using the newly set root password
	mysqladmin -u root -p"${SQL_ROOT_PASSWORD}" shutdown

	printf '%b\n' "${GREEN}Inception: Database setup completed successfully.${RESETCOLOR}"
else
	# If the folder already exists, it means the setup was already done in a previous run.
	printf '%b\n' "${GREEN}Inception: Database already initialized. Skipping setup.${RESETCOLOR}"
fi

printf '%b\n' "${GRAY}Inception: Starting MariaDB daemon in foreground...${RESETCOLOR}"

# Start the database in foreground
#	exec replaces the shell process with mysqld_safe, making it PID 1.
#	This ensures the container stays alive and receives stop signals correctly
exec mysqld_safe

# Perché @'%' invece di @'localhost'?
# Nella riga della creazione dell'utente, SQL_USER@'%' permette all'utente di
# connettersi da qualsiasi indirizzo IP. Dato che WordPress e MariaDB sono in
# due container separati (e quindi hanno due IP diversi all'interno della rete Docker),
# se avessimo usato localhost WordPress sarebbe stato bloccato.

# Perché exec mysqld_safe alla fine?
# Se avessimo usato solo mysqld_safe senza exec, lo script bash sarebbe rimasto il
# processo PID 1 e MariaDB sarebbe diventato un processo figlio. Questo causerebbe
# problemi quando spegni il container, perché Docker invierebbe il segnale di
# spegnimento a bash, che non lo passerebbe a MariaDB, costringendo Docker a
# "killarlo" in malo modo e rischiando di corrompere i dati.