################################################################################
#                                                                              #
#   INCEPTION MAKEFILE                                                         #
#                                                                              #
################################################################################

NAME        = inception
LOGIN       = mcecchel
DATA_PATH   = /home/$(LOGIN)/data

# Path to the docker-compose.yml file (located inside the srcs/ directory)
COMPOSE_FILE = ./srcs/docker-compose.yml

# Base command (mandatory services only: mariadb, wordpress, nginx)
COMPOSE      = docker compose -f $(COMPOSE_FILE)
# Command with the "bonus" profile enabled: needed for commands that must also see
# bonus services (down, ps, logs). Without the profile, Compose ignores those containers
# and "make down" would leave adminer running.
COMPOSE_ALL  = $(COMPOSE) --profile bonus

# **************************************************************************** #
#    RULES                                                                     #
# **************************************************************************** #

# Main target: creates host directories and builds/starts the containers
all: up

# Creates the host directories required for volumes BEFORE starting Docker.
# This prevents Docker from creating them automatically with root ownership.
prepare:
	@echo "Creating host data directories for volumes in $(DATA_PATH)..."
	@mkdir -p $(DATA_PATH)/db_data
	@mkdir -p $(DATA_PATH)/wp_data

# Starts containers in the background, building images if necessary.
# Starts mandatory services only: bonus services ("bonus" profile) stay stopped.
# The initial down uses COMPOSE_ALL so it also removes any leftover adminer
# from a previous "make bonus".
up: prepare
	@echo "Removing existing containers..."
	@$(COMPOSE_ALL) down --remove-orphans
	@echo "Starting $(NAME) containers..."
	@$(COMPOSE) up -d --build --remove-orphans

# Starts mandatory + bonus services (currently Adminer only).
# Skips the initial down: already running mandatory containers stay up.
bonus: prepare
	@echo "Starting $(NAME) containers with bonus services..."
	@$(COMPOSE_ALL) up -d --build --remove-orphans

# Stops and removes running containers
down:
	@echo "Stopping $(NAME) containers..."
	@$(COMPOSE_ALL) down

# Displays container status
status:
	@$(COMPOSE_ALL) ps

# Streams logs for all services in real time
logs:
	@$(COMPOSE_ALL) logs -f

# Standard cleanup: stops containers and removes unused images/networks
clean: down
	@echo "Cleaning unused Docker resources..."
	@docker system prune -a --force

# Deep cleanup: removes containers, networks, Docker volumes, and host directories.
# Files inside those directories belong to container users (mysql, root),
# so root permissions are required to delete them.
fclean: clean
	@echo "Removing persistent data and volumes..."
	@docker volume rm db_data wp_data 2>/dev/null || true
	@sudo rm -rf $(DATA_PATH)/db_data $(DATA_PATH)/wp_data

re: fclean all

.PHONY: all prepare up bonus down status logs clean fclean re