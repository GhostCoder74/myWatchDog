PREFIX=/usr/local
ETC_DIR=/etc/myWatchDog
SERVICE_DIR=$(ETC_DIR)/services
BIN=$(PREFIX)/bin/myWatchDog.sh
SRC=src
CONF_SRC=examples/etc
CRONTAB_FILE=/etc/cron.d/mywatchdog
CRON_FILE=$(CONF_SRC)/crontab.example

FORCE ?= 0    # Standardmäßig kein Force
DRY_RUN ?= 0  # Standardmäßig echte Installation

install:
	@echo "=== Installing myWatchDog ==="

	# Hilfsfunktion für Dry-Run
	@echo "Dry-run mode: $(DRY_RUN), Force mode: $(FORCE)"
	@echo "Simulating commands..." || true

	# Verzeichnisse erstellen
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		if [ ! -d "$(ETC_DIR)" ]; then \
			echo "[DRY-RUN] mkdir -p $(ETC_DIR)"; \
		else \
			echo "[DRY-RUN] $(ETC_DIR) already exists"; \
		fi; \
	else \
		if [ ! -d "$(ETC_DIR)" ] || [ "$(FORCE)" -eq 1 ]; then \
			echo "Creating directory $(ETC_DIR)"; \
			mkdir -p $(ETC_DIR); \
		else \
			echo "$(ETC_DIR) already exists"; \
		fi; \
	fi

	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		if [ ! -d "$(SERVICE_DIR)" ]; then \
			echo "[DRY-RUN] mkdir -p $(SERVICE_DIR)"; \
		else \
			echo "[DRY-RUN] $(SERVICE_DIR) already exists"; \
		fi; \
	else \
		if [ ! -d "$(SERVICE_DIR)" ] || [ "$(FORCE)" -eq 1 ]; then \
			echo "Creating directory $(SERVICE_DIR)"; \
			mkdir -p $(SERVICE_DIR); \
		else \
			echo "$(SERVICE_DIR) already exists"; \
		fi; \
	fi

	# main.conf installieren
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		if [ ! -f "$(ETC_DIR)/main.conf" ]; then \
			echo "[DRY-RUN] install -m 600 $(CONF_SRC)/myWatchDog/main.conf $(ETC_DIR)/"; \
		else \
			echo "[DRY-RUN] $(ETC_DIR)/main.conf exists"; \
		fi; \
	else \
		if [ ! -f "$(ETC_DIR)/main.conf" ] || [ "$(FORCE)" -eq 1 ]; then \
			echo "Installing main.conf to $(ETC_DIR)/"; \
			install -m 600 $(CONF_SRC)/myWatchDog/main.conf $(ETC_DIR)/; \
		else \
			echo "main.conf already exists in $(ETC_DIR)/"; \
		fi; \
	fi

	# Beispiel-Configs kopieren
	@for f in $(CONF_SRC)/myWatchDog/services/*; do \
		dest="$(SERVICE_DIR)/$$(basename $$f)"; \
		if [ "$(DRY_RUN)" -eq 1 ]; then \
			if [ ! -f "$$dest" ]; then \
				echo "[DRY-RUN] cp -r $$f $$dest"; \
			else \
				echo "[DRY-RUN] $$dest exists"; \
			fi; \
		else \
			if [ ! -f "$$dest" ] || [ "$(FORCE)" -eq 1 ]; then \
				cp -r "$$f" "$$dest"; \
				echo "Copied $$f to $$dest"; \
			else \
				echo "$$dest already exists, skipping"; \
			fi; \
		fi; \
	done

	# Script installieren
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		if [ ! -f "$(BIN)" ]; then \
			echo "[DRY-RUN] install -m 755 $(SRC)/myWatchDog.sh $(BIN)"; \
		else \
			echo "[DRY-RUN] $(BIN) exists"; \
		fi; \
	else \
		if [ ! -f "$(BIN)" ] || [ "$(FORCE)" -eq 1 ]; then \
			echo "Installing myWatchDog.sh to $(BIN)"; \
			install -m 755 $(SRC)/myWatchDog.sh $(BIN); \
		else \
			echo "$(BIN) already exists, skipping"; \
		fi; \
	fi

	# Verzeichnisbaum anzeigen
	@if command -v tree >/dev/null 2>&1; then \
		echo "Installed directory structure:"; \
		tree -L 2 $(ETC_DIR) || true; \
	else \
		echo "tree command not found, showing default structure:"; \
		echo "$(ETC_DIR)/"; \
		echo "├── main.conf"; \
		echo "└── services"; \
		echo "    ├── process-service.conf.example"; \
		echo "    ├── script-service.conf.example"; \
		echo "    └── systemd-service.conf.example"; \
		echo "$(BIN)/"; \
		echo "└── myWatchDog.sh"; \
	fi

	# Cronjob installieren
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		if [ ! -f "$(CRONTAB_FILE)" ]; then \
			echo "[DRY-RUN] install -m 644 $(CRON_FILE) $(CRONTAB_FILE)"; \
		else \
			echo "[DRY-RUN] $(CRONTAB_FILE) exists"; \
		fi; \
	else \
		if [ ! -f "$(CRONTAB_FILE)" ] || [ "$(FORCE)" -eq 1 ]; then \
			echo "Installing default crontab file to $(CRONTAB_FILE)"; \
			install -m 644 $(CRON_FILE) $(CRONTAB_FILE); \
		else \
			echo "$(CRONTAB_FILE) already exists, skipping"; \
		fi; \
	fi

	# Cron-Verzeichnisbaum anzeigen
	@echo "Cron structure:"
	@if command -v tree >/dev/null 2>&1; then \
		tree -L 1 /etc/cron.d/ || true; \
	else \
		echo "/etc/cron.d/"; \
		echo "└── mywatchdog"; \
	fi

	@echo "=== Installation complete ==="
