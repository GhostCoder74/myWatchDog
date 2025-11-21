PREFIX=/usr
APP_NAME=myWatchDog
ETC_DIR=/etc/$(APP_NAME)
SERVICE_DIR=$(ETC_DIR)/services
LOGO_DIR=$(PREFIX)/share/$(APP_NAME)
BIN=$(PREFIX)/local/bin/$(APP_NAME).sh
SRC=src
CONF_SRC=examples/etc
CRONTAB_FILE=/etc/cron.d/mywatchdog
CRON_FILE=$(CONF_SRC)/crontab.example

FORCE ?= 0
DRY_RUN ?= 0

.PHONY: install uninstall show

install:
	@echo "=== Installing $(APP_NAME) ==="
	@echo "Dry-run: $(DRY_RUN) | Force: $(FORCE)"

	# --- Directories ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] mkdir -p $(ETC_DIR)"; \
		echo "[DRY-RUN] mkdir -p $(SERVICE_DIR)"; \
		echo "[DRY-RUN] mkdir -p $(LOGO_DIR)"; \
	else \
		mkdir -p $(ETC_DIR); \
		mkdir -p $(SERVICE_DIR); \
		mkdir -p $(LOGO_DIR); \
	fi

	# --- main.conf ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] install -m 600 $(CONF_SRC)/$(APP_NAME)/main.conf $(ETC_DIR)/"; \
	else \
		if [ ! -f "$(ETC_DIR)/main.conf" ] || [ "$(FORCE)" -eq 1 ]; then \
			install -m 600 $(CONF_SRC)/$(APP_NAME)/main.conf $(ETC_DIR)/; \
		else \
			echo "$(ETC_DIR)/main.conf exists, skipping"; \
		fi; \
	fi

	# --- Logos ---
	@for f in $(LOGO_DIR)/*.jepg; do \
		dest="$(LOGO_DIR)/$$(basename $$f)"; \
		if [ "$(DRY_RUN)" -eq 1 ]; then \
			echo "[DRY-RUN] cp $$f $$dest"; \
		else \
			if [ ! -f "$$dest" ] || [ "$(FORCE)" -eq 1 ]; then \
				cp "$$f" "$$dest"; \
				echo "Installed $$dest"; \
			else \
				echo "$$dest exists, skipping"; \
			fi; \
		fi; \
	done

	# --- Example-Configs ---
	@for f in $(CONF_SRC)/$(APP_NAME)/services/*; do \
		dest="$(SERVICE_DIR)/$$(basename $$f)"; \
		if [ "$(DRY_RUN)" -eq 1 ]; then \
			echo "[DRY-RUN] cp $$f $$dest"; \
		else \
			if [ ! -f "$$dest" ] || [ "$(FORCE)" -eq 1 ]; then \
				cp "$$f" "$$dest"; \
				echo "Installed $$dest"; \
			else \
				echo "$$dest exists, skipping"; \
			fi; \
		fi; \
	done

	# --- Main script ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] install -m 755 $(SRC)/$(APP_NAME).sh $(BIN)"; \
	else \
		if [ ! -f "$(BIN)" ] || [ "$(FORCE)" -eq 1 ]; then \
			install -m 755 $(SRC)/$(APP_NAME).sh $(BIN); \
		else \
			echo "$(BIN) exists, skipping"; \
		fi; \
	fi

	# --- Setup Crontab ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] install -m 644 $(CRON_FILE) $(CRONTAB_FILE)"; \
	else \
		if [ ! -f "$(CRONTAB_FILE)" ] || [ "$(FORCE)" -eq 1 ]; then \
			install -m 644 $(CRON_FILE) $(CRONTAB_FILE); \
		else \
			echo "$(CRONTAB_FILE) exists, skipping"; \
		fi; \
	fi

	@echo "=== Installation complete ==="

# -------------------------------------------------------------------
# UNINSTALL – Removes EVERYTHING, but respects DRY_RUN
# -------------------------------------------------------------------
uninstall:
	@echo "=== Uninstalling $(APP_NAME) ==="
	@echo "Dry-run: $(DRY_RUN)"

	# Remove files & directories
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] rm -f $(BIN)"; \
		echo "[DRY-RUN] rm -f $(CRONTAB_FILE)"; \
		echo "[DRY-RUN] rm -rf $(ETC_DIR)"; \
	else \
		rm -f $(BIN); \
		rm -f $(CRONTAB_FILE); \
		rm -rf $(ETC_DIR); \
	fi

	@echo "=== Uninstall complete ==="

# -------------------------------------------------------------------
# SHOW – shows structure of the installation
# -------------------------------------------------------------------
show:
	@echo "=== $(APP_NAME) installation overview ==="

	@if command -v tree >/dev/null 2>&1; then \
		if [ -d "$(ETC_DIR)" ]; then \
			tree -L 2 $(ETC_DIR); \
		else \
			echo "$(ETC_DIR) not found"; \
		fi; \
		if [ -d "$(LOGO_DIR)" ]; then \
			tree -L 2 $(LOGO_DIR); \
		else \
			echo "$(LOGO_DIR) not found"; \
		fi; \
	else \
		echo "tree command not found — fallback:"; \
		if [ -d "$(ETC_DIR)" ]; then \
			echo "$(ETC_DIR)/"; \
			echo "├── main.conf"; \
			echo "├── logo"; \
			echo "└── services"; \
			ls -1 $(SERVICE_DIR) | awk '{a[NR]=$$0} END{for(i=1;i<NR;i++)printf "    ├── %s\n",a[i]; printf "    └── %s\n",a[NR]}'; \
		else \
			echo "$(ETC_DIR) does not exist."; \
		fi; \
		if [ -d "$(LOGO_DIR)" ]; then \
			echo "$(LOGO_DIR)/"; \
			ls -1 $(LOGO_DIR) | awk '{a[NR]=$$0} END{for(i=1;i<NR;i++)printf "    ├── %s\n",a[i]; printf "    └── %s\n",a[NR]}'; \
		else \
			echo "$(LOGO_DIR) does not exist."; \
		fi; \
	fi

	@if [ -f "$(BIN)" ]; then \
		echo "$(BIN)"; \
	else \
		echo "$(BIN) missing"; \
	fi

	@if [ -f "$(CRONTAB_FILE)" ]; then \
		echo "/etc/cron.d/mywatchdog"; \
	else \
		echo "/etc/cron.d/mywatchdog not found"; \
	fi

	@echo "=== Show complete ==="

