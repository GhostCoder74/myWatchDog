PREFIX=/usr/local
ETC_DIR=/etc/myWatchDog
SERVICE_DIR=$(ETC_DIR)/services
BIN=$(PREFIX)/bin/myWatchDog.sh
SRC=src
CONF_SRC=examples/etc
CRONTAB_FILE=/etc/cron.d/mywatchdog
CRON_FILE=$(CONF_SRC)/crontab.example

FORCE ?= 0
DRY_RUN ?= 0

.PHONY: install uninstall show

install:
	@echo "=== Installing myWatchDog ==="
	@echo "Dry-run: $(DRY_RUN) | Force: $(FORCE)"

	# --- Directories ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] mkdir -p $(ETC_DIR)"; \
		echo "[DRY-RUN] mkdir -p $(SERVICE_DIR)"; \
	else \
		mkdir -p $(ETC_DIR); \
		mkdir -p $(SERVICE_DIR); \
	fi

	# --- main.conf ---
	@if [ "$(DRY_RUN)" -eq 1 ]; then \
		echo "[DRY-RUN] install -m 600 $(CONF_SRC)/myWatchDog/main.conf $(ETC_DIR)/"; \
	else \
		if [ ! -f "$(ETC_DIR)/main.conf" ] || [ "$(FORCE)" -eq 1 ]; then \
			install -m 600 $(CONF_SRC)/myWatchDog/main.conf $(ETC_DIR)/; \
		else \
			echo "$(ETC_DIR)/main.conf exists, skipping"; \
		fi; \
	fi

	# --- Example-Configs ---
	@for f in $(CONF_SRC)/myWatchDog/services/*; do \
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
		echo "[DRY-RUN] install -m 755 $(SRC)/myWatchDog.sh $(BIN)"; \
	else \
		if [ ! -f "$(BIN)" ] || [ "$(FORCE)" -eq 1 ]; then \
			install -m 755 $(SRC)/myWatchDog.sh $(BIN); \
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
	@echo "=== Uninstalling myWatchDog ==="
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
	@echo "=== myWatchDog installation overview ==="

	@if command -v tree >/dev/null 2>&1; then \
		if [ -d "$(ETC_DIR)" ]; then \
			tree -L 2 $(ETC_DIR); \
		else \
			echo "$(ETC_DIR) not found"; \
		fi; \
	else \
		echo "tree command not found — fallback:"; \
		if [ -d "$(ETC_DIR)" ]; then \
			echo "$(ETC_DIR)/"; \
			echo "├── main.conf"; \
			echo "└── services"; \
			ls -1 $(SERVICE_DIR) | sed 's/^/    ├── /'; \
		else \
			echo "$(ETC_DIR) does not exist."; \
		fi; \
	fi

	@if [ -f "$(BIN)" ]; then \
		echo "$(BIN) exists"; \
	else \
		echo "$(BIN) missing"; \
	fi

	@if [ -f "$(CRONTAB_FILE)" ]; then \
		echo "/etc/cron.d/mywatchdog installed"; \
	else \
		echo "/etc/cron.d/mywatchdog not found"; \
	fi

	@echo "=== Show complete ==="

