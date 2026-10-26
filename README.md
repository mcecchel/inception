*This project has been created as part of the 42 curriculum by mcecchel.*

# Inception

## Description

Inception is a system administration project that asks students to build a small web infrastructure from scratch using Docker containers.
The goal is to set up a fully functional **WordPress website** served over **HTTPS**, backed by a **MariaDB database**, and reverse-proxied through **NGINX** — all managed with **Docker Compose** inside a virtual machine.

Every service runs in its own dedicated container, built from a custom Dockerfile based on Debian Linux (bullseye/bookworm). No pre-built service images are pulled from Docker Hub; only the base OS layer is used.
The project enforces strict security practices: credentials are managed through a `.env` file, TLS is the only accepted protocol (TLSv1.2/TLSv1.3), and no passwords appear in Dockerfiles or version-controlled files.

### Architecture overview

Inception is built as a Docker Compose project. Docker Compose is a Docker plugin that lets you build and run multiple containers, their networks, volumes, and dependencies in a single command. All configurations are defined in a declarative YAML file (`docker-compose.yml`).

The three services communicate with each other via a custom Docker bridge network (`inception`). This virtual network is isolated from the host computer's network, except for port 443, which is open and bound to port 443 of the host machine. Port 443 is the only entrypoint of the project, used to access the WordPress website.

Data persistence is handled by Docker local volumes mapped to directories on the host filesystem (`/home/mcecchel/data/`). Two volumes are used: one for the database (`db_data`) and one for the WordPress and NGINX files (`wp_data`). NGINX accesses `wp_data` in read-only mode to serve static files, while WordPress and MariaDB access their respective volumes in read-write mode.

```console
            ┌──────────────────────────────────────────────────────────────────┐
            │ Docker Compose (inception)                                       │
            │                                                                  │
            │ ┌──────────────────────────────────────────────────────────────┐ │
            │ │ Docker network: inception (bridge)                           │ │
            │ │                                                              │ │
 HTTPS :443 │ │  ┌─────────┐  FastCGI  ┌───────────┐    TCP    ┌───────────┐ │ │
────────────┼─┼─►│  NGINX  │──────────►│ WordPress │──────────►│  MariaDB  │ │ │
            │ │  │  (TLS)  │   :9000   │ (PHP-FPM) │   :3306   │   (DB)    │ │ │
            │ │  └────┬────┘           └─────┬─────┘           └─────┬─────┘ │ │
            │ │       │                      │                       │       │ │
            │ └───────┼──────────────────────┼───────────────────────┼───────┘ │
            │         │                      │                       │         │
            │         │ ro                   │ rw                    │ rw      │
            │         │                      │                       │         │
            │         │                      │                       ▼         │
            │         │    ┌───────────┐     │                 ┌───────────┐   │
            │         └───►│  wp_data  │◄────┘                 │  db_data  │   │
            │              │  (volume) │                       │  (volume) │   │
            │              └───────────┘                       └───────────┘   │
            │                                                                  │
            └──────────────────────────────────────────────────────────────────┘
```

**Services:**

| Service | Container | Role | Port |
| ------- | --------- | ---- | ---- |
| **nginx** | `nginx` | TLS termination, reverse proxy, static files | 443 (host) |
| **wordpress** | `wordpress` | PHP-FPM application server, WP-CLI bootstrap | 9000 (internal) |
| **mariadb** | `mariadb` | Relational MySQL database server | 3306 (internal) |

**Volumes:**

| Volume | Host path | Container mount | Purpose |
| ------ | --------- | --------------- | ------- |
| `wp_data` | `/home/mcecchel/data/wp_data` | `/var/www/html` | WordPress site files |
| `db_data` | `/home/mcecchel/data/db_data` | `/var/lib/mysql` | MariaDB database files |

---

## Instructions

### Prerequisites

- A Linux virtual machine (Debian recommended).
- **Docker Engine** and **Docker Compose**.
- **GNU Make**.
- `sudo` access to modify host files and create directories.

### DNS configuration

To allow local domain resolution, add this line to your `/etc/hosts` file on the host machine:

```text
127.0.0.1   mcecchel.42.fr
```

### Setup and Execution

1. Navigate to the root directory containing the `Makefile`.
2. Rename `srcs/.env.example` to `srcs/.env` and fill in all the required environment variables (passwords, domain name, etc.).
3. Run the following command to create the host directories, build the images, and start the containers:

```bash
make up
```

### Accessing the site

| URL | Description |
| --- | ----------- |
| `https://mcecchel.42.fr` | WordPress front page |
| `https://mcecchel.42.fr/wp-admin` | WordPress admin panel |

*Note: The browser will warn about a self-signed TLS certificate — this is expected.*

### Makefile Commands

| Command | Action |
| ------- | ------ |
| `make all` / `make up` | Creates host directories and starts containers in the background. |
| `make down` | Stops and removes containers (data is preserved in volumes). |
| `make status` | Shows the status of running containers. |
| `make logs` | Displays real-time logs for all services. |
| `make clean` | Stops containers and prunes unused Docker resources. |
| `make fclean` | Deep clean: removes containers, networks, Docker volumes, and host data directories. |
| `make re` | Executes `fclean` followed by `all` to rebuild everything from scratch. |

---

## Project description

### Docker and containerization

**Docker** is a platform that packages applications and their dependencies into lightweight, portable units called **containers**. Unlike traditional VMs, Docker containers share the host kernel but run in isolated user-space environments, making them faster to start and reproducible across different machines.

In this project, Docker is used to run three independent services (NGINX, WordPress, and MariaDB). **Docker Compose** orchestrates them as a single stack described in `docker-compose.yml`, automating the creation of networks, volumes, and container interdependencies.

### Design choices

- **Debian Base:** Images are built from the penultimate stable version of Debian, providing a stable and familiar ecosystem while complying with the 42 subject constraints.
- **Custom Entrypoints:** Bash scripts are used as entrypoints (`exec "$@"`) to handle automated setup (like WP-CLI installations and MariaDB bootstrapping) while replacing the shell with the main service process (PID 1) to ensure graceful shutdowns.
- **No Infinite Loops:** Commands like `tail -f` or `sleep infinity` are strictly avoided.

---

### Virtual Machines vs Docker

- **Virtual Machines (VMs):** VMs emulate a complete physical computer via a hypervisor (e.g., VirtualBox). Each VM runs its own full operating system kernel, providing strong hardware-level isolation at the cost of high CPU, memory, and disk overhead.
- **Docker Containers:** Containers share the host OS kernel and virtualize only the application layer (process-level isolation via namespaces and cgroups). They are extremely lightweight, start in seconds, and have minimal resource overhead. 
- **Use in this project:** Inception runs Docker containers to manage the microservices, but the entire environment is hosted inside a Virtual Machine to provide a controlled, sandboxed development space as required by the curriculum.

### Secrets vs Environment Variables

- **Environment Variables:** Passed into the container's process environment at runtime. They are easy to implement via a `.env` file but can be exposed through debugging tools or process listings. 
- **Docker Secrets:** Mounted as read-only files (usually in `/run/secrets/`) directly into the container, keeping them completely hidden from the environment variables and image layers.
- **Use in this project:** The 42 subject mandates the use of environment variables stored in a `.env` file. While Docker secrets are generally recommended for production, the `.env` approach was strictly implemented to fulfill the project's requirements.

### Docker Network vs Host Network

- **Host Network:** The container shares the host's networking namespace directly. All ports opened by the container are exposed on the host, increasing the risk of port conflicts and reducing security isolation. The `network: host` directive is explicitly forbidden by the subject.
- **Docker Bridge Network:** A private virtual network managed by Docker. It provides automatic DNS resolution by service name (e.g., WordPress can reach MariaDB simply by pinging `mariadb`). 
- **Use in this project:** A custom bridge network named `inception` isolates the services. Only the NGINX port (`443`) is exposed to the outside world, keeping the database and PHP-FPM securely hidden.

### Docker Volumes vs Bind Mounts

- **Docker Volumes:** Storage managed entirely by Docker, usually stored in `/var/lib/docker/volumes/`. They are portable and decoupled from the host's specific directory structure.
- **Bind Mounts:** Direct mappings of a specific host path into the container. They rely heavily on the host's filesystem permissions and structure. Standard bind mounts are forbidden for persistent storage in this project.
- **Use in this project:** The subject requires the use of Docker named volumes, but mandates that the data must physically reside in `/home/mcecchel/data/` on the host. To achieve this, local named volumes are defined with `driver_opts` that bind them to the required host directories.

---

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker compose file reference](https://docs.docker.com/reference/compose-file/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [MariaDB Server documentation](https://mariadb.com/kb/en/documentation/)
- [WP-CLI documentation](https://developer.wordpress.org/cli/commands/)
- [Virtual machines vs Docker containers](https://medium.com/@ravipatel.it/understanding-virtual-machines-vs-docker-containers-a-technical-comparison-241f370b2076)

### AI usage disclosure

AI tools were used during development to:
- Verify that Dockerfiles, entrypoints, and `docker-compose.yml` satisfy the 42 subject constraints (no forbidden patterns, proper PID 1 handling...).
- Check structure entrypoint scripts to proper error handling and idempotent bootstrap logic.
- Help structure the documentation files and check for errors/refuses (`README.md`, `USER_DOC.md`, `DEV_DOC.md`).
- Debug errors from containers' runtime logs.