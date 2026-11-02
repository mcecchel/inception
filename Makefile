################################################################################
#                                                                              #
#   INCEPTION MAKEFILE                                                         #
#                                                                              #
################################################################################

NAME        = inception
LOGIN       = mcecchel
DATA_PATH   = /home/$(LOGIN)/data

# Percorso del file docker-compose.yml (si trova nella cartella srcs/)
COMPOSE_FILE = ./srcs/docker-compose.yml

# **************************************************************************** #
#    RULES                                                                     #
# **************************************************************************** #

# Target principale: crea le cartelle sull'host ed effettua la build/up
all: prepare up

# Crea le cartelle sull'host necessarie ai volumi PRIMA di avviare Docker.
# In questo modo eviti che Docker le crei automaticamente con permessi da root.
prepare:
	@echo "Creating host data directories for volumes in $(DATA_PATH)..."
	@mkdir -p $(DATA_PATH)/db_data
	@mkdir -p $(DATA_PATH)/wp_data

# Avvia i container in background costruendo le immagini se necessario
up: prepare
	@echo "Removing existing containers..."
	@docker compose -f $(COMPOSE_FILE) down --remove-orphans
	@echo "Starting $(NAME) containers..."
	@docker compose -f $(COMPOSE_FILE) up -d --build --remove-orphans

# Ferma e rimuove i container in esecuzione
down:
	@echo "Stopping $(NAME) containers..."
	@docker compose -f $(COMPOSE_FILE) down

# Mostra lo stato dei container
status:
	@docker compose -f $(COMPOSE_FILE) ps

# Mostra i log di tutti i servizi in tempo reale
logs:
	@docker compose -f $(COMPOSE_FILE) logs -f

# Pulizia standard: ferma i container e rimuove immagini/reti inutilizzate
clean: down
	@echo "Cleaning unused Docker resources..."
	@docker system prune -a --force

# Pulizia profonda: rimuove container, reti, volumi Docker e cancella le cartelle sull'host.
# I file nelle cartelle appartengono agli utenti interni ai container (mysql, root),
# quindi servono i permessi di root per cancellarli.
fclean: clean
	@echo "Removing persistent data and volumes..."
	@docker volume rm db_data wp_data 2>/dev/null || true
	@sudo rm -rf $(DATA_PATH)/db_data $(DATA_PATH)/wp_data

re: fclean all