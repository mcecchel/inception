# Inception — Developer Documentation

This document describes the technical architecture, environment setup, deployment process, and container management for developers maintaining or evaluating the Inception project.

---

## Table of contents

1. [Project structure](#project-structure)
2. [Prerequisites](#prerequisites)
3. [Environment setup](#environment-setup)
4. [Building and launching](#building-and-launching)
5. [Service architecture](#service-architecture)
6. [Data persistence and storage](#data-persistence-and-storage)
7. [Entrypoint scripts and PID 1](#entrypoint-scripts-and-pid-1)
8. [Useful commands](#useful-commands)
9. [Troubleshooting](#troubleshooting)

---

## Project structure

The repository strictly isolates configuration files inside `srcs/` and keeps only the `Makefile` and documentation files at the root level, complying with 42 project requirements:

```
inception/
├── Makefile                               # Root Makefile controlling Docker Compose
├── README.md                              # General project overview and technical comparisons
├── USER_DOC.md                            # End-user documentation
├── DEV_DOC.md                             # This file
└── srcs/
    ├── .env                               # Environment variables (git-ignored)
    ├── .env.example                       # Template for environment variables
    ├── docker-compose.yml                 # Service, network, and volume orchestration
    └── requirements/                      # Build requirements for each service
        ├── mariadb/
        │   ├── Dockerfile                 # MariaDB container build instructions (Debian)
        │   ├── conf/
        │   │   └── mariadb.conf           # MariaDB server configuration
        │   └── tools/
        │       └── mariadb_entrypoint.sh  # Database initialization script
        ├── nginx/
        │   ├── Dockerfile                 # NGINX container build instructions (Debian)
        │   ├── conf/
        │   │   └── nginx.conf             # NGINX server configuration
        │   └── tools/
        │       └── nginx_entrypoint.sh    # TLS certificate generation script
        └── wordpress/
            ├── Dockerfile                 # WordPress/PHP-FPM container build instructions (Debian)
            ├── conf/
            │   └── www.conf               # PHP-FPM pool configuration
            └── tools/
                └── wp_entrypoint.sh       # WP-CLI automated installation script
```

---

## Prerequisites

### Host environment

To build and run this infrastructure, the host machine requires:

- **Linux OS** (Debian 11/12 recommended inside a Virtual Machine).
- **Docker Engine** (v20.10+).
- **Docker Compose** plugin (v2+).
- **GNU Make**.
- **`sudo` access** (to manage `/etc/hosts` and host data directories under `/home/mcecchel/data`).

### Verification

Ensure Docker and Docker Compose are installed and functional:

```bash
docker --version
docker compose version
make --version
```

---

## Environment setup

### 1. Environment file (`srcs/.env`)

All sensitive credentials and non-sensitive configurations are passed to the containers via environment variables stored in `srcs/.env`.

To set up the environment file:

```bash
cp srcs/.env.example srcs/.env
```

Edit `srcs/.env` with your editor of choice. The file must define:

| Variable | Purpose | Example / Required value |
| -------- | ------- | ------------------------ |
| `DOMAIN_NAME` | Host domain name | `mcecchel.42.fr` |
| `SQL_DATABASE` | MariaDB database name | `wordpress` |
| `SQL_USER` | MariaDB application user | `wp_user` |
| `SQL_PASSWORD` | MariaDB application password | `wp_password` |
| `SQL_ROOT_PASSWORD` | MariaDB root password | `root_password` |
| `WP_ADMIN_USER` | WordPress admin login | `mcecchel` *(cannot contain admin/Administrator)* |
| `WP_ADMIN_PASSWORD` | WordPress admin password | `admin_pass_123` |
| `WP_ADMIN_EMAIL` | WordPress admin email | `mcecchel@student.42.fr` |
| `WP_USER` | WordPress author user | `user42` |
| `WP_USER_PASSWORD` | WordPress author password | `user_pass_123` |
| `WP_USER_EMAIL` | WordPress author email | `user42@student.42.fr` |

> **Security Note:** `srcs/.env` is excluded from version control via `.gitignore`. Never commit actual passwords to Git.

### 2. DNS Resolution

Add the local domain mapping to `/etc/hosts` on the host machine:

```bash
127.0.0.1   mcecchel.42.fr
```

---

## Building and launching

The root `Makefile` automates directory creation, image building, and container orchestration.

### Common Makefile Targets

| Command | Internal Action |
| ------- | --------------- |
| `make up` / `make all` | Creates `/home/mcecchel/data/` directories, builds Docker images if missing, and starts containers in detached mode. |
| `make down` | Stops and removes containers while keeping volume data intact. |
| `make status` | Displays the status of active containers (`docker compose ps`). |
| `make logs` | Displays container logs (`docker compose logs`). |
| `make clean` | Stops containers and removes unused Docker images/resources. |
| `make fclean` | Stops containers, removes images/volumes, and deletes data in `/home/mcecchel/data/`. |
| `make re` | Runs `fclean` followed by `make up` to rebuild the entire stack from scratch. |

---

## Service architecture

```
               ┌────────────────────────────────────────────────────────┐
               │ Docker Bridge Network: inception                       │
               │                                                        │
 HTTPS (443)   │   ┌──────────┐    FastCGI (9000)   ┌───────────┐       │
───────────────┼──►│  NGINX   │────────────────────►│ WordPress │       │
               │   │  (TLS)   │                     │ (PHP-FPM) │       │
               │   └────┬─────┘                     └─────┬─────┘       │
               │        │                                 │             │
               │        │                                 │ TCP (3306)  │
               │        │                                 ▼             │
               │        │                           ┌───────────┐       │
               │        │                           │  MariaDB  │       │
               │        │                           │   (DB)    │       │
               │        │                           └─────┬─────┘       │
               └────────┼─────────────────────────────────┼─────────────┘
                        │                                 │
                        ▼                                 ▼
                 /home/mcecchel/                   /home/mcecchel/
                 data/wp_data                      data/db_data
```

### 1. NGINX
- **Role:** Web server, TLS termination, reverse proxy for PHP requests, static asset host.
- **Port:** Exposes port `443` to the host machine.
- **Protocols:** Strictly TLSv1.2 and TLSv1.3 (`ssl_protocols TLSv1.2 TLSv1.3;`).
- **Communication:** Communicates with WordPress over port `9000` via FastCGI inside the isolated Docker network.

### 2. WordPress (PHP-FPM)
- **Role:** Executes PHP code for WordPress using FastCGI Process Manager.
- **Port:** Internal port `9000` (not published to the host).
- **Automation:** Uses WP-CLI inside its entrypoint script to automatically download, configure, and install WordPress without relying on interactive browser wizards.
- **Users Created:** 
  1. Administrator (`WP_ADMIN_USER`).
  2. Author (`WP_USER`).

### 3. MariaDB
- **Role:** Relational database management system.
- **Port:** Internal port `3306` (not published to the host).
- **Configuration:** Bound to `0.0.0.0` to accept connections from the `wordpress` container over the Docker bridge network.

---

## Data persistence and storage

Data persistence is guaranteed using Docker local named volumes configured with `driver_opts` to bind directly to host directory paths under `/home/mcecchel/data/`.

| Volume Name | Host Directory Path | Container Mounting Point | Access Mode |
| ----------- | ------------------- | ------------------------ | ----------- |
| `db_data` | `/home/mcecchel/data/db_data` | `/var/lib/mysql` (MariaDB) | Read-Write (`rw`) |
| `wp_data` | `/home/mcecchel/data/wp_data` | `/var/www/html` (WordPress) | Read-Write (`rw`) |
| `wp_data` | `/home/mcecchel/data/wp_data` | `/var/www/html` (NGINX) | Read-Only (`ro`) |

### Volume Setup in `docker-compose.yml`:

```yaml
volumes:
  db_data:
    name: db_data
    driver: local
    driver_opts:
      type: none
      device: /home/mcecchel/data/db_data
      o: bind

  wp_data:
    name: wp_data
    driver: local
    driver_opts:
      type: none
      device: /home/mcecchel/data/wp_data
      o: bind
```

---

## Entrypoint scripts and PID 1

To strictly avoid hacky patches like `tail -f`, `sleep infinity`, or infinite `while` loops (forbidden by the 42 subject), every service uses an entrypoint script that ends with `exec "$@"`.

### Why `exec` is Mandatory:
- Using `exec` replaces the shell process (`/bin/sh` or `/bin/bash`) with the target service binary (e.g., `nginx`, `php-fpm8.2`, or `mariadbd`).
- This ensures the daemon becomes **PID 1** inside the container.
- PID 1 receives POSIX signals directly (e.g., `SIGTERM`, `SIGINT`), allowing Docker to stop containers cleanly without hanging or leaving zombie processes.

### Idempotent Bootstrap Pattern:
Entrypoint scripts verify if initial setup has already occurred before executing commands:
- **MariaDB:** Checks if `/var/lib/mysql/${SQL_DATABASE}` exists. If absent, runs database initialization and SQL user creation scripts.
- **WordPress:** Checks for `/var/www/html/wp-config.php`. If absent, uses WP-CLI to download files, generate configuration, run core installation, and create users.
- **NGINX:** Checks if TLS certificates (`/etc/nginx/ssl/nginx.crt`) exist. If absent, generates self-signed certificates via OpenSSL.

---

## Useful commands

### Container Shell Access
To inspect the internal state of a running container:

```bash
docker exec -it nginx sh
docker exec -it wordpress sh
docker exec -it mariadb sh
```

### Inspecting Docker Networks
To verify that services are isolated on the `inception` bridge network:

```bash
docker network inspect inception
```

### Testing NGINX TLS Protocol
To confirm NGINX accepts only TLS 1.2 / 1.3:

```bash
openssl s_client -connect mcecchel.42.fr:443 -tls1_3
```

---

## Troubleshooting

### 1. WordPress fails to connect to MariaDB on initial startup
- **Cause:** MariaDB container is still initializing system tables when WordPress starts.
- **Solution:** The `wp_entrypoint.sh` includes a retry loop using `mariadb-admin ping` to wait until MariaDB responds on port 3306 before running WP-CLI setup commands.

### 2. File permission issues on `/home/mcecchel/data`
- **Cause:** Host directories were created by Docker with `root` ownership.
- **Solution:** The `Makefile` automatically creates `/home/mcecchel/data/db_data` and `/home/mcecchel/data/wp_data` before running `docker compose up`. If permissions are broken, reset host ownership:
  ```bash
  sudo chown -R $USER:$USER /home/mcecchel/data
  ```