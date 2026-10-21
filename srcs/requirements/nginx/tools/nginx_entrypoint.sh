#!/bin/sh

# ANSI escape codes for terminal messages
RED='\033[0;31m'
GRAY='\033[0;90m'
GREEN='\033[0;32m'
RESETCOLOR='\033[0m'

# Execute a command and stop the container if it fails
#	step_name="$1" saves the first argument, which describes the operation
#	shift removes the first argument, so the command to execute remains
#	if ! "$@" runs the command and checks if it fails. If it fails, enter the block then
run_step() {
	step_name="$1"
	shift

	if ! "$@"; then
		printf '%b\n' \
			"${RED}Inception: ${step_name} failed. Exiting.${RESETCOLOR}" >&2
		exit 1
	fi
}

printf '%b\n' "${GRAY}Inception: Checking domain configuration...${RESETCOLOR}"

# DOMAIN_NAME must be provided through the container environment
#	The :- syntax safely handles an unset variable when using /bin/sh
#	Without a domain, we cannot generate the certificate for the intended host
if [ -z "${DOMAIN_NAME:-}" ]; then
	printf '%b\n' \
		"${RED}Inception: DOMAIN_NAME is not set.${RESETCOLOR}" >&2
	exit 1
fi

# Define the paths used to store the TLS certificate and private key
SSL_DIR="/etc/nginx/ssl"
CERT_FILE="${SSL_DIR}/inception.crt"
KEY_FILE="${SSL_DIR}/inception.key"

# Generate a certificate only if the certificate or private key is missing or empty.
# This avoids regenerating them on every container start
#	-s checks if the file exists and is not empty
#	! to invert the condition
#	|| the block runs if either file is missing or empty
#	NB: this check does not verify expiration or certificate/domain matching.
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
	printf '%b\n' \
		"${GREEN}Inception: SSL configuration in progress...${RESETCOLOR}"

	# Create the directory for the TLS files if it does not already exist.
	# The -p option also creates missing parent directories and avoids an error
	# when the directory already exists.
	run_step "SSL directory creation" mkdir -p "$SSL_DIR"

	printf '%b\n' "Inception: Generating self-signed certificate..."

	# Generate a self-signed X.509 certificate and a new RSA private key.
	# -x509: create a certificate directly instead of a certificate request.
	# -nodes: do not encrypt the private key with a passphrase, so Nginx
	#         can start unattended without waiting for interactive input.
	# -newkey rsa:2048: generate a new 2048-bit RSA private key.
	# -keyout: path where the private key is written.
	# -out: path where the certificate is written.
	# -days 365: set the certificate validity to 365 days.
	# -subj: set the certificate subject without interactive questions.
	# -addext: add the Subject Alternative Name (SAN) extension.
	#          Modern TLS clients use SAN to verify the requested hostname.
	# A self-signed certificate is not automatically trusted by browsers.
	run_step "SSL certificate generation" \
		openssl req \
			-x509 \
			-nodes \
			-newkey rsa:2048 \
			-keyout "$KEY_FILE" \
			-out "$CERT_FILE" \
			-days 365 \
			-subj "/CN=${DOMAIN_NAME}" \
			-addext "subjectAltName=DNS:${DOMAIN_NAME}"
fi

# With exec, nginx replaces this shell process, becoming PID 1
#	-g "daemon off;" tells Nginx to run in the foreground, so the container does not die
exec nginx -g "daemon off;"
# ------------------------------------------------------------------------------


# Execute a command and stop the container if it fails.
# The first argument is a description of the step.
# "shift" removes that description, leaving only the command and its arguments.
# "$@" preserves the remaining arguments as separate parameters.
run_step() {
	step_name="$1"
	shift

	if ! "$@"; then
		printf '%b\n' \
			"${RED}Inception: ${step_name} failed. Exiting.${RESETCOLOR}" >&2
		exit 1
	fi
}

# DOMAIN_NAME must be provided through the container environment.
# The :- syntax safely handles an unset variable when using /bin/sh.
# Without a domain, we cannot generate the certificate for the intended host.
if [ -z "${DOMAIN_NAME:-}" ]; then
	printf '%b\n' \
		"${RED}Inception: DOMAIN_NAME is not set.${RESETCOLOR}" >&2
	exit 1
fi

# Define the paths used to store the TLS certificate and private key.
SSL_DIR="/etc/nginx/ssl"
CERT_FILE="${SSL_DIR}/inception.crt"
KEY_FILE="${SSL_DIR}/inception.key"

# Generate a certificate only if the certificate or private key is missing or empty.
# This avoids regenerating them on every container start
#	NB: this check does not verify expiration or certificate/domain matching.
if [ ! -s "$CERT_FILE" ] || [ ! -s "$KEY_FILE" ]; then
	printf '%b\n' \
		"${GREEN}Inception: SSL configuration in progress...${RESETCOLOR}"

	# Create the directory for the TLS files if it does not already exist.
	# The -p option also creates missing parent directories and avoids an error
	# when the directory already exists.
	run_step "SSL directory creation" mkdir -p "$SSL_DIR"

	printf '%b\n' "Inception: Generating self-signed certificate..."

	# Generate a self-signed X.509 certificate and a new RSA private key.
	# -x509: create a certificate directly instead of a certificate request.
	# -nodes: do not encrypt the private key with a passphrase, so Nginx
	#         can start unattended without waiting for interactive input.
	# -newkey rsa:2048: generate a new 2048-bit RSA private key.
	# -keyout: path where the private key is written.
	# -out: path where the certificate is written.
	# -days 365: set the certificate validity to 365 days.
	# -subj: set the certificate subject without interactive questions.
	# -addext: add the Subject Alternative Name (SAN) extension.
	#          Modern TLS clients use SAN to verify the requested hostname.
	# A self-signed certificate is not automatically trusted by browsers.
	run_step "SSL certificate generation" \
		openssl req \
			-x509 \
			-nodes \
			-newkey rsa:2048 \
			-keyout "$KEY_FILE" \
			-out "$CERT_FILE" \
			-days 365 \
			-subj "/CN=${DOMAIN_NAME}" \
			-addext "subjectAltName=DNS:${DOMAIN_NAME}"

	# Restrict access to the private key to its owner.
	# The certificate can be shared publicly, but the private key must remain
	# secret. The container's user and directory permissions also matter.
	run_step "Private key permissions" chmod 600 "$KEY_FILE"

	printf '%b\n' \
		"${GREEN}Inception: SSL configured successfully!${RESETCOLOR}"
else
	# Reuse existing files instead of generating a new certificate at startup.
	printf '%b\n' "Inception: Existing SSL certificate found."
fi

# Start the command supplied by Docker (CMD).
# "$@" passes all arguments to the command without merging them into one string.
# exec replaces this shell process with Nginx, allowing Nginx to run as PID 1
# and receive container stop signals directly.
printf '%b\n' "Inception: Starting NGINX..."
exec "$@"
