#!/bin/bash
# --------------------------------------------------------------------
# myWatchDog – Advanced Service & Process Monitor
# Copyright (C) 2025 Christian Klose <ghostcoder@gmx.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.
# --------------------------------------------------------------------

# =====================================================================
# myWatchDog.sh – Universal Monitoring Script
# Config: /etc/myWatchDog/main.conf
# Services: /etc/myWatchDog/services/*.conf
# Params:
#  --test / -t           : Test mode (no real restarts)
#  --restart / -r        : Force restart (works in test)
#  --mode / -m <mode>    : daily | weekly | monthly
#  --get-chatid / -i     : Start OTP pairing workflow for Telegram
#  -h / --help           : show help
# =====================================================================

VERSION="20251118.0.1"
BASECONFIG="/etc/myWatchDog/main.conf"
SERVICE_DIR="/etc/myWatchDog/services"
STATE_DIR="/run/myWatchDog"
mkdir -p "$STATE_DIR"

TEST_MODE=0
FORCE_RESTART=0
MODE=""           # "daily" / "weekly" / "monthly"
MODE_SUFFIX=""    # computed from MODE: "", "_daily", ...

NL='%0A'
TESTMODE_STR="!!! TESTMODE !!!"

SECRET_FILE="$STATE_DIR/myWatchDog.otp"

# ------------------------------
# Helper: help
# ------------------------------
show_help() {
cat <<EOF
Usage: $0 [options]

Options:
  --test, -t              Test mode (no real restarts)
  --restart, -r           Force restart in test mode
  --mode, -m MODE         Mode: daily, weekly, monthly
  --get-chatid, -i        Start OTP pairing to get chat id via Telegram
  -h, --help              Show this help
EOF
}

# ------------------------------
# Parse args
# ------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --test|-t)
            TEST_MODE=1
            shift
            ;;
        --restart|-r)
            FORCE_RESTART=1
            shift
            ;;
        --mode|-m)
            if [ -n "$2" ]; then
                MODE="$2"
                MODE_SUFFIX="_$MODE"
                shift 2
            else
                echo "Error: --mode requires an argument (daily|weekly|monthly)"
                exit 2
            fi
            ;;
        --get-chatid|-i)
            SECRET=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 2
            ;;
    esac
done

# ------------------------------
# Utils
# ------------------------------
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

# Log into journalctl
log() {
    local TAG="$1"; shift
    local MSG="$*"
    logger -t "$TAG" "$MSG"
    echo "[$(timestamp)] $TAG: $MSG"
}

# Send telegram and parse response
send_telegram() {
    local PREFIX="$1"; shift
    local MSG="$*"
    local FULLMSG="📡 <b>Watchdog: </b><code>${PREFIX}</code>$NL$NL <b>Server:</b>$NL<pre>$(hostname -f)</pre>$NL<b>$(timestamp)</b>$NL$NL${MSG}"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
        return 0
    fi

    local json_result
    json_result=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$FULLMSG" \
        -d parse_mode="HTML")

    # parse success or error
    # If success -> [, ok:true, result.message_id]
    # If error   -> [, ok:false, error_code, description]
    local tg_result
    tg_result=($(jq -r '
        if .ok == true then
            [(.ok|tostring), (.result.message_id|tostring)]
        else
            [(.ok|tostring), (.error_code|tostring), (.description)]
        end | @tsv' <<< "$json_result"))

    if [ "${tg_result[0]}" = "true" ]; then
        log "telegram-watchdog[${PREFIX}]" "TG send ok, msg_id=${tg_result[1]}"
    else
        log "telegram-watchdog[${PREFIX}]" "TG send failed: ${json_result}"
    fi
}

# ------------------------------
# INI parser (robust against spaces around '=')
# ------------------------------
get_ini_value() {
    local file="$1"
    local section="$2"
    local key="$3"
        
    awk -F'=' -v section="[$section]" -v key="$key" '
        function trim(s) {
            sub(/^[ \t\r\n]+/, "", s)
            sub(/[ \t\r\n]+$/, "", s)
            return s
        }
        $0 == section { in_section=1; next }
        /^\[.*\]/ { in_section=0 }
        in_section {
            k = trim($1)
            v = trim($2)
            if (k == key) {
                print v
                exit
            }
        }   
    ' "$file"
} 

# ------------------------------
# OTP / pairing
# ------------------------------
get_secret() {
    # loop: generate OTP, wait for user to confirm "GESENDET"
    while true; do
        OTP=$(shuf -i 100000-999999 -n 1)
        EXPIRE=$(( $(date +%s) + 120 ))
        echo "${OTP}:${EXPIRE}" > "$SECRET_FILE"
        chmod 600 "$SECRET_FILE"

        echo ""
        echo "Please send this to the Telegram group where you added your myWatchDog bot:"
        echo ""
        echo "   /getchatid $OTP"
        echo ""
	echo "The secret is valid for 2 minutes (until: $(date -d @$EXPIRE))."
	echo -n 'When sent, please enter OK (in capital letters):'

        read -r USER_INPUT

        NOW=$(date +%s)
        if [ "$NOW" -ge "$EXPIRE" ]; then
            echo ""
            echo "⛔ Time exceeded! Secret was only valid for 2 minutes. Generate new secret..."
            continue    # new OTP and new timeout
        fi

        if [ "$USER_INPUT" = "OK" ]; then
            get_chat_id "$OTP"
            return $?
        else
	    echo "❌ Invalid input! Try again (new secret will be generated)."
            continue    # regenerate OTP per your earlier requirement
        fi
    done
}

# ------------------------------
# get_chat_id: looks up the /getchatid <OTP> message in updates
# ------------------------------
get_chat_id() {
    local secret="$1"
    local PREFIX="Get-Chat-Id"
    if [ -z "$secret" ]; then
        echo "ERROR: No SECRET given!"
        return 1
    fi
    local json_result
    json_result=$(curl -s -X GET "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates")
    # select last matching message with exact text "/getchatid <secret>"
    chat_id=$(jq -r --arg sec "$secret" '
        [.result[] | select(.message and (.message.text == ("/getchatid " + $sec))) | .message.chat.id]
        | if length>0 then .[-1] else "" end' <<< "$json_result")
    chat_title=$(jq -r --arg sec "$secret" '
        [.result[] | select(.message and (.message.text == ("/getchatid " + $sec))) | .message.chat.title]
        | if length>0 then .[-1] else "" end' <<< "$json_result")

    if [ -z "$chat_id" ]; then
        echo "ERROR: No SECRET found in bot updates."
        return 1
    fi

    log "telegram-watchdog[${PREFIX}]" "Found chat_id=${chat_id} title='${chat_title}' for secret=${secret}"
    echo "Die Chat-ID lautet: \"$chat_id\""
    echo "Der Chat-Titel lautet: \"$chat_title\""

    rm -f "$SECRET_FILE"
    return 0
}

# ------------------------------
# perform_cmd / perform_restart
# ------------------------------
perform_cmd() {
    local name="$1"; local tag="$2"; local prefix="$3"; shift 3
    local cmd="$*"

    local jq_filter='if (has("message")) then .message else to_entries | map("<b>"+.key+"</b>: "+.value) | join("\n") end'
    local result
    result="$(eval "$cmd" | jq -r "$jq_filter" 2>/dev/null || echo "no-json-output")"

    if [ "$TEST_MODE" -eq 1 ] && [ "$FORCE_RESTART" -eq 0 ]; then
        log "$tag" "$TESTMODE_STR: simulated run of $name"
        send_telegram "$prefix${MODE_SUFFIX}" "$TESTMODE_STR$NL<pre>$name simulated</pre>$NL$result"
    else
        log "$tag" "run: $cmd"
        log "$tag" "result: $result"
        send_telegram "$prefix${MODE_SUFFIX}" "<pre>$name executed</pre>$NL$result"
    fi
}

perform_restart() {
    local name="$1"; local cmd="$2"; local tag="$3"; local prefix="$4"

    if [ "$TEST_MODE" -eq 1 ] && [ "$FORCE_RESTART" -eq 0 ]; then
        log "$tag" "$TESTMODE_STR: simulated restart of $name"
        send_telegram "$prefix${MODE_SUFFIX}" "$TESTMODE_STR$NL<pre>Restart simulated: $name</pre>"
    else
        log "$tag" "restart: $cmd"
        eval "$cmd"
        send_telegram "$prefix${MODE_SUFFIX}" "🔁<pre>$name restarted</pre>"
    fi
}

# ------------------------------
# check_systemd_service -> returns 0=OK,1=warn(stalled),2=restart needed
# ------------------------------
check_systemd_service() {
    local SVC="$1"

    local ACTIVE
    ACTIVE=$(systemctl is-active "$SVC" 2>/dev/null)
    local FAILED
    FAILED=$(systemctl is-failed "$SVC" 2>/dev/null)
    local SUB
    SUB=$(systemctl show -p SubState "$SVC" | cut -d= -f2)

    local PID
    PID=$(systemctl show -p MainPID "$SVC" | cut -d= -f2)

    # -----------------------------------------------------
    # 1⃣ Dienst inaktiv / dead → sofort Neustart
    # -----------------------------------------------------
    if [[ "$ACTIVE" != "active" && "$ACTIVE" != "activating" ]]; then
        return 2
    fi

    # -----------------------------------------------------
    # 2⃣ Dienst läuft, aber PID = 0 oder verschwunden
    # -----------------------------------------------------
    if [[ -z "$PID" || "$PID" -eq 0 ]]; then
        return 2
    fi

    # -----------------------------------------------------
    # 3⃣ D-State oder Zombie → Neustart
    # -----------------------------------------------------
    local STATE
    STATE=$(ps -o s= -p "$PID" 2>/dev/null)

    [[ "$STATE" == "D" ]] && return 2
    [[ "$STATE" == "Z" ]] && return 2

    # -----------------------------------------------------
    # 4⃣ /proc/$PID/stat fehlt → Prozess hart abgestürzt
    # -----------------------------------------------------
    if [ ! -f "/proc/$PID/stat" ]; then
        return 2
    fi

    # -----------------------------------------------------
    # 5⃣ CPU-Jiffies (Userzeit + Kernelzeit)
    # Freeze Detection
    # -----------------------------------------------------
    local STATEFILE="/var/run/myWatchDog/${SVC}.state"

    CPU_TIME=$(awk '{print $14+$15}' /proc/$PID/stat)
    LAST_CPU_TIME=$(cat "$STATEFILE.cputime" 2>/dev/null || echo 0)

    # Keine Änderung → Prozess hängt
    if [ "$CPU_TIME" -eq "$LAST_CPU_TIME" ]; then
        if [ -f "$STATEFILE.stalled" ]; then
            rm -f "$STATEFILE.cputime" "$STATEFILE.stalled"
            return 2
        else
            echo stalled > "$STATEFILE.stalled"
            echo "$CPU_TIME" > "$STATEFILE.cputime"
            return 1   # Warnung, aber noch kein Neustart
        fi
    fi

    # Fortschritt vorhanden → sauber
    echo "$CPU_TIME" > "$STATEFILE.cputime"
    rm -f "$STATEFILE.stalled"

    return 0
}

# ------------------------------
# check_process -> returns 0=OK,1=warn(stalled),2=restart needed
# ------------------------------
check_process() {
    local PROC="$1"
    local PID
    PID=$(pgrep -f "$PROC" | head -1)

    local STATEFILE="/var/run/myWatchDog/${PROC}.state"

    # -----------------------------------------------------
    # 1⃣ Prozess existiert NICHT
    # -----------------------------------------------------
    if [ -z "$PID" ]; then
        return 2
    fi

    # -----------------------------------------------------
    # 2⃣ Prozessstatus auslesen
    # -----------------------------------------------------
    local STATE
    STATE=$(ps -o s= -p "$PID" 2>/dev/null)

    # D-State → Prozess hängt hart
    [[ "$STATE" == "D" ]] && return 2

    # Zombie-Prozess
    [[ "$STATE" == "Z" ]] && return 2

    # -----------------------------------------------------
    # 3⃣ /proc/$PID/stat fehlt → Prozess weg
    # -----------------------------------------------------
    if [ ! -f "/proc/$PID/stat" ]; then
        return 2
    fi

    # -----------------------------------------------------
    # 4⃣ CPU-Jiffies für Freeze-Detection
    # -----------------------------------------------------
    local CPU_TIME LAST_CPU_TIME

    CPU_TIME=$(awk '{print $14+$15}' /proc/$PID/stat 2>/dev/null)
    LAST_CPU_TIME=$(cat "$STATEFILE.cputime" 2>/dev/null || echo 0)

    # CPU steht still → Prozess frozen
    if [ "$CPU_TIME" -eq "$LAST_CPU_TIME" ]; then
        if [ -f "$STATEFILE.stalled" ]; then
            rm -f "$STATEFILE.cputime" "$STATEFILE.stalled"
            return 2         # zweiter Freeze → Neustart
        else
            echo stalled > "$STATEFILE.stalled"
            echo "$CPU_TIME" > "$STATEFILE.cputime"
            return 1         # erster Freeze → Warnung
        fi
    fi

    # -----------------------------------------------------
    # 5⃣ Alles OK → Fortschritt gespeichert
    # -----------------------------------------------------
    echo "$CPU_TIME" > "$STATEFILE.cputime"
    rm -f "$STATEFILE.stalled"

    return 0
}

# ------------------------------
# Load main config
# ------------------------------
if [ ! -f "$BASECONFIG" ]; then
    echo "❌ Fehler: $BASECONFIG nicht gefunden!"
    exit 1
fi

LOG_TAG=$(get_ini_value "$BASECONFIG" "General" "log_tag")
TELEGRAM_BOT_TOKEN=$(get_ini_value "$BASECONFIG" "Telegram" "bot_token")
# pick chat id by mode suffix (empty, _daily, _weekly, _monthly)
TELEGRAM_CHAT_ID=$(get_ini_value "$BASECONFIG" "Telegram" "chat_id${MODE_SUFFIX}")
DBG_TG_JSON=$(get_ini_value "$BASECONFIG" "Telegram" "dbg_json")
DBG_TG_JSON=${DBG_TG_JSON:-false}
CPU_DEFAULT=$(get_ini_value "$BASECONFIG" "Defaults" "cpu_threshold")
[ -z "$LOG_TAG" ] && LOG_TAG="mywatchdog"

# If user asked for OTP flow
if [ -n "${SECRET:-}" ]; then
    get_secret
    exit $?
fi

# ------------------------------
# Main loop: iterate services
# ------------------------------
for CONF in "$SERVICE_DIR"/*.conf; do
    [ ! -f "$CONF" ] && continue

    # defaults (global)
    NOTIFY_SUCCESS=$(get_ini_value "$BASECONFIG" "Telegram" "notify_success")
    NOTIFY_SUCCESS=${NOTIFY_SUCCESS:-false}
    LOG_NOTIFY_SUCCESS=$(get_ini_value "$BASECONFIG" "Logging" "notify_success")
    LOG_NOTIFY_SUCCESS=${LOG_NOTIFY_SUCCESS:-false}

    SECTION=$(grep -o '^\[[A-Za-z]\+\]' "$CONF" | head -1 | tr -d '[]')

    SERVICE_NAME=$(get_ini_value "$CONF" "Service" "name")
    PROCESS_NAME=$(get_ini_value "$CONF" "Process" "name")
    TYPE=$(get_ini_value "$CONF" "Service" "type")
    [ -z "$TYPE" ] && TYPE=$(get_ini_value "$CONF" "Process" "type")

    CPU_THRESHOLD=$(get_ini_value "$CONF" "Service" "cpu_threshold")
    [ -z "$CPU_THRESHOLD" ] && CPU_THRESHOLD=$(get_ini_value "$CONF" "Process" "cpu_threshold")
    [ -z "$CPU_THRESHOLD" ] && CPU_THRESHOLD="$CPU_DEFAULT"

    RESTART_CMD=$(get_ini_value "$CONF" "Service" "restart_cmd")
    [ -z "$RESTART_CMD" ] && RESTART_CMD=$(get_ini_value "$CONF" "Process" "restart_cmd")

    SCRIPT_CMD=$(get_ini_value "$CONF" "Service" "script_cmd${MODE_SUFFIX}")
    [ -z "$SCRIPT_CMD" ] && SCRIPT_CMD=$(get_ini_value "$CONF" "Script" "script_cmd${MODE_SUFFIX}")

    ALERT_PREFIX=$(get_ini_value "$CONF" "Alert" "message_prefix")
    ALERT_ENABLED=$(get_ini_value "$CONF" "Alert" "enabled")
    TAG=$(get_ini_value "$CONF" "Logging" "tag")
    [ -z "$TAG" ] && TAG="$LOG_TAG"

    STATEFILE="$STATE_DIR/$(basename "$CONF" .conf).state"

    # per-service override of notify flags
    if [[ "$(get_ini_value "$CONF" "Telegram" "notify_success")" == "true" ]]; then
        NOTIFY_SUCCESS="true"
    fi
    if [[ "$(get_ini_value "$CONF" "Logging" "notify_success")" == "true" ]]; then
        LOG_NOTIFY_SUCCESS="true"
    fi

    # Security: skip if no name configured
    if [ -z "$SERVICE_NAME" ] && [ -z "$PROCESS_NAME" ]; then
        log "$TAG" "⚠ No name found in $CONF, skipped"
        continue
    fi

    # ------------------------------
    # systemd
    # ------------------------------
    if [ "$TYPE" = "systemd" ]; then
        CHECK=0
        CHECK=$(check_systemd_service "$SERVICE_NAME")
        CHECK=${CHECK:-0}
        case "$CHECK" in
            0)
                [ "$NOTIFY_SUCCESS" = "true" ] && send_telegram "$ALERT_PREFIX" "✅ Service $SERVICE_NAME runs normal"
                [ "$LOG_NOTIFY_SUCCESS" = "true" ] && log "$TAG" "✅ Service $SERVICE_NAME runs normal"
                ;;
            1)
		log "$TAG" "⚠ $SERVICE_NAME shows no activity (temporary freeze)"
                ;;
            2)
                log "$TAG" "❌ $SERVICE_NAME crashed/frozen – restart"
                perform_restart "$SERVICE_NAME" "$RESTART_CMD" "$TAG" "$ALERT_PREFIX"
                ;;
            *)
                log "$TAG" "❓ Unknown error: $CHECK"
                ;;
        esac
        # cleanup per-service statefiles: keep cputime for next run, remove stalled if OK
        # statefiles are maintained inside check_ functions; do not overwrite here
        continue
    fi

    # ------------------------------
    # script type
    # ------------------------------
    if [ "$TYPE" = "script" ]; then
        log "$TAG" "$SERVICE_NAME is now running!"
        perform_cmd "$SERVICE_NAME" "$TAG" "$ALERT_PREFIX" "$SCRIPT_CMD"
        continue
    fi

    # ------------------------------
    # process
    # ------------------------------
    if [ "$TYPE" = "process" ]; then
        CHECK=$(check_process "$PROCESS_NAME")
        CHECK=${CHECK:-0}
        case "$CHECK" in
            0)
                [ "$NOTIFY_SUCCESS" = "true" ] && send_telegram "$ALERT_PREFIX" "✅ Process $PROCESS_NAME runs normal"
                [ "$LOG_NOTIFY_SUCCESS" = "true" ] && log "$TAG" "✅ Process $PROCESS_NAME runs normal"
                ;;
            1)
		log "$TAG" "⚠ Process $PROCESS_NAME is not responding (no CPU progress)"
                ;;
            2)
                log "$TAG" "❌ Process $PROCESS_NAME crashed – restart"
                perform_restart "$PROCESS_NAME" "$RESTART_CMD" "$TAG" "$ALERT_PREFIX"
                ;;
            *)
                log "$TAG" "❓ Unknown error: $CHECK"
                ;;
        esac
        continue
    fi

done

exit 0
