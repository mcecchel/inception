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

# Comando base (solo mandatory: mariadb, wordpress, nginx)
COMPOSE      = docker compose -f $(COMPOSE_FILE)
# Comando con il profilo "bonus" attivo: serve ai comandi che devono vedere anche
# i servizi bonus (down, ps, logs). Senza profilo, Compose ignora quei container
# e "make down" lascerebbe adminer in esecuzione.
COMPOSE_ALL  = $(COMPOSE) --profile bonus

# **************************************************************************** #
#    RULES                                                                     #
# **************************************************************************** #

# Target principale: crea le cartelle sull'host ed effettua la build/up
all: up

# Crea le cartelle sull'host necessarie ai volumi PRIMA di avviare Docker.
# In questo modo eviti che Docker le crei automaticamente con permessi da root.
prepare:
	@echo "Creating host data directories for volumes in $(DATA_PATH)..."
	@mkdir -p $(DATA_PATH)/db_data
	@mkdir -p $(DATA_PATH)/wp_data

# Avvia i container in background costruendo le immagini se necessario.
# Parte solo il mandatory: i servizi bonus (profilo "bonus") restano spenti.
# Il down iniziale usa COMPOSE_ALL cosi' rimuove anche un eventuale adminer
# rimasto da un precedente "make bonus".
up: prepare
	@echo "Removing existing containers..."
	@$(COMPOSE_ALL) down --remove-orphans
	@echo "Starting $(NAME) containers..."
	@$(COMPOSE) up -d --build --remove-orphans

# Avvia il mandatory + i servizi bonus (per ora solo Adminer).
# Non fa il down iniziale: i container mandatory gia' attivi restano in piedi.
bonus: prepare
	@echo "Starting $(NAME) containers with bonus services..."
	@$(COMPOSE_ALL) up -d --build --remove-orphans

# Ferma e rimuove i container in esecuzione
down:
	@echo "Stopping $(NAME) containers..."
	@$(COMPOSE_ALL) down

# Mostra lo stato dei container
status:
	@$(COMPOSE_ALL) ps

# Mostra i log di tutti i servizi in tempo reale
logs:
	@$(COMPOSE_ALL) logs -f

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

.PHONY: all prepare up bonus down status logs clean fclean re