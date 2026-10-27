# Inception — User Documentation

This document explains how to use the Inception stack as an end user or administrator. It covers the services provided, how to start and stop the project, how to access the website, where credentials are stored, and how to verify that everything is running correctly.

---

## Table of contents

1. [What does Inception provide?](#what-does-inception-provide)
2. [Prerequisites](#prerequisites)
3. [Starting the project](#starting-the-project)
4. [Stopping the project](#stopping-the-project)
5. [Accessing the website](#accessing-the-website)
6. [Accessing the administration panel](#accessing-the-administration-panel)
7. [Locating and managing credentials](#locating-and-managing-credentials)
8. [Checking that services are running correctly](#checking-that-services-are-running-correctly)
9. [Common operations](#common-operations)
10. [Troubleshooting](#troubleshooting)

---

## What does Inception provide?

Inception deploys a complete WordPress website with three cooperating services:

| Service | What it does |
| ------- | ------------ |
| **NGINX** | The web server and single entry point. It terminates TLS (HTTPS on port 443), serves static files, and forwards PHP requests to WordPress. |
| **WordPress + PHP-FPM** | The application server. It executes the WordPress PHP code and communicates with the database. It does not serve HTTP directly — NGINX handles that. |
| **MariaDB** | The relational database. It stores all WordPress content: posts, pages, users, settings, and plugin/theme data. |

The three services communicate over an isolated Docker network. Only port **443 (HTTPS)** is exposed to the host machine. Internal ports (PHP-FPM 9000, MariaDB 3306) are not accessible from outside the Docker network.

All website files and database data are stored persistently on the host machine under `/home/mcecchel/data/`, so content survives container restarts and rebuilds.

---

## Prerequisites

### Required software

Before running the project, install the following tools on your Linux host:

| Package | Why it is needed |
| ------- | ---------------- |
| **Docker Engine** | Runs the containers |
| **Docker Compose plugin** | Runs `docker compose` commands |
| **make** | Runs project commands (`make up`, `make fclean`, etc.) |
| **sudo** | Required to create host data directories securely |

### Install commands (Debian/Ubuntu)

Since the project is designed for a Debian-based virtual machine, run the following commands to install the base dependencies:

```bash
sudo apt update
sudo apt install -y ca-certificates curl gnupg make sudo
```

Then, to install Docker, follow the official [Debian Docker installation guide](https://docs.docker.com/engine/install/debian/#install-using-the-repository).

### Verify installation

```bash
docker --version
docker compose version
make --version
```

---

## Starting the project

### First-time setup

If this is the first time running the project on this machine, you need to configure your environment variables:

1. Navigate to the `srcs/` directory.
2. Create your `.env` file by copying the template or creating a new one:
   ```bash
   cp .env.example .env
   ```
3. Open `.env` with a text editor and fill in your secure passwords and configuration (make sure `DOMAIN_NAME` is set to `mcecchel.42.fr`).

Once the `.env` file is ready, go back to the root directory (where the `Makefile` is) and start the stack:

```bash
make up
```

This will:
1. Automatically create the host data directories (`/home/mcecchel/data/db_data`, `/home/mcecchel/data/wp_data`).
2. Build all three Docker images from source based on Debian.
3. Start the containers in the background.

### Subsequent starts

To start the stack if it was previously stopped (without rebuilding images):

```bash
make up
```

To forcefully rebuild images (e.g., after changing a Dockerfile or configuration) and start the stack from scratch, use:

```bash
make re
```

---

## Stopping the project

### Stop and remove containers (preserve data)

```bash
make down
```

This stops all containers and removes them, but the data stored in `/home/mcecchel/data/` and the Docker volumes are preserved. Running `make up` afterwards will recreate the containers with the same data.

### Full cleanup

```bash
make fclean
```

This removes containers, images, networks, volumes, **and** deletes the host data directories (`/home/mcecchel/data/db_data`, `/home/mcecchel/data/wp_data`).
> **Attention**: All WordPress content and database data will be permanently lost!

---

## Accessing the website

### DNS configuration

Before accessing the site by domain name, make sure your host machine resolves the domain locally. Add this line to `/etc/hosts` on your host machine:

```text
127.0.0.1   mcecchel.42.fr
```

### Opening the website

Open a web browser and navigate to:

```text
https://mcecchel.42.fr
```

Your browser will display a security warning because the TLS certificate is self-signed. This is expected and safe for local development:

- **Firefox**: Click *Advanced* → *Accept the Risk and Continue*.
- **Chrome**: Click *Advanced* → *Proceed to mcecchel.42.fr (unsafe)*.
- **curl**: Use the `-k` flag to ignore the certificate check: `curl -k https://mcecchel.42.fr`.

You will see the WordPress front page once the stack is fully initialized.

---

## Accessing the administration panel

The WordPress admin dashboard is available at:

```text
https://mcecchel.42.fr/wp-admin
```

Log in using the **administrator credentials** defined in your `srcs/.env` file (`WP_ADMIN_USER` and `WP_ADMIN_PASSWORD`).

From the admin panel you can:
- Create and edit posts and pages.
- Manage users and their roles.
- Install themes and plugins.
- Configure site settings (title, URLs, reading preferences, etc.).

Two WordPress users are created during setup based on your `.env` variables:
1. **Administrator:** Managed by `WP_ADMIN_USER`
2. **Author (regular user):** Managed by `WP_USER`

---

## Locating and managing credentials

### Where credentials are stored

Unlike setups that use separate Docker secret files, this project stores all configuration and sensitive credentials in a single environment file located at:

```text
srcs/.env
```

The file contains the following variables:

| Variable | Description |
| -------- | ----------- |
| `DOMAIN_NAME` | Website domain name (`mcecchel.42.fr`) |
| `SQL_DATABASE` | MariaDB database name |
| `SQL_USER` | MariaDB application user login |
| `SQL_PASSWORD` | MariaDB application user password |
| `SQL_ROOT_PASSWORD` | MariaDB root password |
| `WP_ADMIN_USER` | WordPress administrator login |
| `WP_ADMIN_PASSWORD` | WordPress administrator password |
| `WP_ADMIN_EMAIL` | WordPress administrator email |
| `WP_USER` | WordPress regular user login |
| `WP_USER_PASSWORD` | WordPress regular user password |
| `WP_USER_EMAIL` | WordPress regular user email |

### Security note

The `srcs/.env` file has been added to `.gitignore`. It is **never committed** to version control, ensuring your passwords remain private and secure on your local machine, fully complying with the 42 subject rules.

### Changing credentials

If you need to change passwords, you must update the `srcs/.env` file and completely reset the infrastructure, as the database and WordPress setup scripts only run on the first initialization:

```bash
# WARNING: This will destroy all current data
make fclean
# Edit srcs/.env with new passwords
make up
```

---

## Checking that services are running correctly

### Quick status check

```bash
make status
```

This shows the status of all three services. You should see `mariadb`, `wordpress`, and `nginx` listed as `Up`.

### Viewing logs

To view the live output and troubleshoot errors from the containers, use:

```bash
make logs
```

To follow logs in real time from a specific container (if you run this manually):

```bash
docker compose -f srcs/docker-compose.yml logs -f mariadb
```

### Testing HTTPS connectivity

From the host machine:

```bash
curl -kI https://mcecchel.42.fr
```

Expected response: `HTTP/1.1 200 OK` (or a `301`/`302` redirect to the WordPress front page). If you get a connection error, verify the containers are running with `make status`.

---

## Common operations

| Task | Command |
| ---- | ------- |
| Start the stack | `make up` |
| Stop the stack | `make down` |
| Show running containers | `make status` |
| View logs | `make logs` |
| Prune unused Docker resources | `make clean` |
| Full reset (destroy data) | `make fclean` |
| Complete rebuild from scratch | `make re` |

---

## Troubleshooting

### Container stays restarting or crashing

The WordPress container waits for MariaDB to be fully healthy before starting its own bootstrap. MariaDB might need extra time on first run to initialize system tables. Check the logs with:

```bash
make logs
```

Look for error messages. Common causes: missing variables in `.env`, incorrect file permissions, or an incompatible Debian base image.

### "Connection refused" on https://...

1. Verify containers are running: `make status`.
2. Verify `/etc/hosts` has the correct entry for your domain.
3. Check the logs to verify NGINX is listening and WordPress PHP-FPM has started successfully.

### Permission denied on /home/mcecchel/data/

The Makefile automatically creates the directories before running `docker compose` to prevent root ownership issues. If you still get permission errors or MariaDB crashes due to writing issues, run:

```bash
sudo chown -R $(id -u):$(id -g) /home/mcecchel/data
chmod -R u+rwX /home/mcecchel/data
```