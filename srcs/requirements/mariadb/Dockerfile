FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
	mariadb-server \
	&& rm -rf /var/lib/apt/lists/*

# COPY <percorso_sul_host> <percorso_nel_container>
# Use a late-loaded filename so the Docker network binding overrides Debian defaults.
COPY ./conf/mariadb.conf /etc/mysql/mariadb.conf.d/99-inception.cnf

# Copy the entrypoint script from the host into the image
COPY ./tools/mariadb_entrypoint.sh /usr/local/bin/mariadb_entrypoint.sh
# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/mariadb_entrypoint.sh

# Exposing ports for MariaDB traffic
EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/mariadb_entrypoint.sh"]