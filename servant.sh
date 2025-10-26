#!/bin/bash
# servant.sh — Adaptive Servant Daemon (permanent systemd timer + smart daily scheduling)
# Features: cross-distro updates, cleanup, Python SMTP email, animated banner & sound,
#           hourly systemd timer + logic to run at preferred times (10,14,20,21) or on-boot fallback,
#           tracks last run in /var/lib/servant/last_run to avoid duplicate runs per day.

# ===================== CONFIGURATION =====================
EMAIL_TO="joshuaura7822@gmail.com"         # <-- change: destination email
EMAIL_FROM="joshuaura7822@gmail.com.com"       # <-- change: sender (Gmail)
EMAIL_PASS="prince7822"      # <-- change: Gmail App Password (or SMTP password)
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT=587
LOGFILE="/var/log/servant.log"
LAST_RUN_DIR="/var/lib/servant"
LAST_RUN_FILE="$LAST_RUN_DIR/last_run"
SERVICE_NAME="servant"
# Preferred run hours (24-hr): tries to run at these hours (local time)
PREFERRED_HOURS=(10 14 20 21)
# ==========================================================

# ---------- Auto-elevate to root if needed ----------
if [ "$EUID" -ne 0 ]; then
    echo "🔐 Escalating privileges with sudo..."
    exec sudo bash "$0" "$@"
fi

# ---------- Helpers ----------
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $*" | tee -a "$LOGFILE"; }

# Make sure directories exist
mkdir -p "$LAST_RUN_DIR"
touch "$LOGFILE"
chown root:root "$LOGFILE"
chmod 644 "$LOGFILE"

# Fancy colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Sound feedback
beep() {
    if command -v paplay &> /dev/null; then
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null &
    elif command -v aplay &> /dev/null; then
        aplay /usr/share/sounds/alsa/Front_Center.wav 2>/dev/null &
    else
        echo -ne "\a"
    fi
}

# ASCII banner (SERVANT)
show_banner() {
    clear
    beep
    echo -e "${CYAN}"
echo "   ◯ ▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩ ◯ "
echo "   ▨                                                                                         ▨ "
echo "   ▨        ███████╗  ███████╗  ██████╗   ██╗   ██╗   █████╗   ███╗   ██╗ █████████╗TM       ▨ "
echo "   ▨        ██╔════╝  ██╔════╝  ██╔══██╗  ██║   ██║  ██╔══██╗  ████╗  ██║     ██╔═╝          ▨ "
echo "   ▨        ███████╗  █████╗    ██████╔╝  ██║   ██║  ███████║  ██╔██╗ ██║     ██╗            ▨ "
echo "   ▨        ╚════██║  ██╔══╝    ██╔══██╗  ██║   ██║  ██╔══██║  ██║╚██╗██║     ██║            ▨ "
echo "   ▨        ███████║  ███████╗  ██║  ██║ ╚  ████ ╔╝  ██║  ██║  ██║ ╚████║     ██║            ▨ "
echo "   ▨        ╚══════╝  ╚══════╝  ╚═╝  ╚═╝   ╚═════╝    ═╝  ╚═╝  ╚═╝  ╚═══╝    ╚══╝            ▨ "
echo "   ▨                                                                                         ▨ " 
echo "   ▨                        🧠 SYSTEM SERVANT DAEMON — UTILITY EDITION®                      ▨ "
echo "   ◯ ▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩ ◯ "

    echo -e "${NC}"
}

# ---------- Utility: read last run date (YYYY-MM-DD) ----------
get_last_run_date() {
    if [ -f "$LAST_RUN_FILE" ]; then
        cat "$LAST_RUN_FILE"
    else
        echo ""
    fi
}

set_last_run_date() {
    local d="$1"
    echo "$d" > "$LAST_RUN_FILE"
    chmod 644 "$LAST_RUN_FILE"
}

# ---------- Determine if we should run maintenance now ----------
should_run_now() {
    # returns 0 (true) if should run, 1 otherwise
    local today=$(date +%F)
    local last=$(get_last_run_date)
    if [ "$last" = "$today" ]; then
        # already ran today
        return 1
    fi

    # current hour (integer 0-23)
    local hour=$(date +%H | sed 's/^0*//')
    hour=${hour:-0}

    # if current hour matches any preferred hour -> run
    for h in "${PREFERRED_HOURS[@]}"; do
        if [ "$hour" -eq "$h" ]; then
            return 0
        fi
    done

    # Not in preferred slot. If we just booted (uptime < 3600s),
    # and the current time is AFTER the last preferred hour of the day,
    # then run as "on-boot fallback"
    local uptime_seconds
    uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 999999)
    local maxpref=${PREFERRED_HOURS[${#PREFERRED_HOURS[@]}-1]}
    # If booted recently (under 1 hour) and current hour > max preferred hour, run.
    if [ "$uptime_seconds" -lt 3600 ] && [ "$hour" -gt "$maxpref" ]; then
        return 0
    fi

    # Also: if we booted recently and none of the preferred slots remain today AND we haven't run today, run.
    # (Covers cases where machine was off during all preferred hours.)
    if [ "$uptime_seconds" -lt 3600 ]; then
        # If current hour is less than or equal to maxpref but still none ran — do NOT run (user wants retries).
        # So only run on-boot if current hour > maxpref (above).
        return 1
    fi

    return 1
}

# ---------- Core maintenance operations ----------
perform_maintenance() {
    show_banner
    log "Servant: starting maintenance attempt."

    # detect distro
    local distro
    if [ -f /etc/debian_version ]; then distro="debian"
    elif [ -f /etc/fedora-release ]; then distro="fedora"
    elif [ -f /etc/arch-release ]; then distro="arch"
    else distro="unknown"
    fi

    log "Detected distro: $distro"

    # Update & upgrade per distro (non-interactive)
    case "$distro" in
        debian)
            log "Running apt update/upgrade..."
            apt update -y >> "$LOGFILE" 2>&1
            apt full-upgrade -y >> "$LOGFILE" 2>&1
            apt autoremove -y >> "$LOGFILE" 2>&1
            apt autoclean -y >> "$LOGFILE" 2>&1
            ;;
        fedora)
            log "Running dnf upgrade..."
            dnf upgrade --refresh -y >> "$LOGFILE" 2>&1
            dnf autoremove -y >> "$LOGFILE" 2>&1
            dnf clean all -y >> "$LOGFILE" 2>&1
            ;;
        arch)
            log "Running pacman -Syu..."
            pacman -Syu --noconfirm >> "$LOGFILE" 2>&1
            # cleanup orphan packages if any
            if command -v pacman &> /dev/null; then
                pacman -Rns --noconfirm $(pacman -Qtdq 2>/dev/null) >> "$LOGFILE" 2>&1 || true
                yes | pacman -Sc >> "$LOGFILE" 2>&1 || true
            fi
            ;;
        *)
            log "Unsupported distro; aborting maintenance."
            return 1
            ;;
    esac

    # Safe log truncation (skip files we can't access)
    log "Cleaning system logs (truncating *.log files it can access)..."
    find /var/log -type f -name "*.log" -print0 | while IFS= read -r -d '' f; do
        truncate -s 0 "$f" 2>/dev/null || true
    done

    # Write last run date (YYYY-MM-DD)
    local today=$(date +%F)
    set_last_run_date "$today"
    log "Maintenance completed; recorded last run date: $today"

    # Build a short summary for email
    local summary="/tmp/servant_summary_$(date +%s).txt"
    {
        echo "Servant maintenance report"
        echo "Host: $(hostname)"
        echo "Date: $(timestamp)"
        echo "Distro: $distro"
        echo ""
        echo "Refer to $LOGFILE for full details."
    } > "$summary"

    # Send email via Python smtplib
    send_email_python "$summary"

    # cleanup summary file
    rm -f "$summary"

    beep
    log "Servant: finished maintenance."
    return 0
}

# ---------- Send email using embedded Python (smtplib) ----------
send_email_python() {
    local summary_file="$1"
    if [ ! -f "$summary_file" ]; then
        echo "No summary file" > "$summary_file"
    fi

    # shell-escape variables safely for the heredoc
    PY_EMAIL_TO="${EMAIL_TO}"
    PY_EMAIL_FROM="${EMAIL_FROM}"
    PY_EMAIL_PASS="${EMAIL_PASS}"
    PY_SMTP_SERVER="${SMTP_SERVER}"
    PY_SMTP_PORT="${SMTP_PORT}"
    PY_SUBJECT="Servant Maintenance Report on $(hostname) - $(date '+%Y-%m-%d')"

    python3 - <<PY3EOF
import smtplib, ssl
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import sys

smtp_server = "${PY_SMTP_SERVER}"
smtp_port = ${PY_SMTP_PORT}
sender = "${PY_EMAIL_FROM}"
receiver = "${PY_EMAIL_TO}"
password = "${PY_EMAIL_PASS}"
subject = "${PY_SUBJECT}"

# read summary file
try:
    with open("${summary_file}", "r") as f:
        body = f.read()
except Exception as e:
    body = "Servant run completed. (Summary file could not be read: {})".format(e)

msg = MIMEMultipart("alternative")
msg["Subject"] = subject
msg["From"] = sender
msg["To"] = receiver
part = MIMEText(body, "plain")
msg.attach(part)

context = ssl.create_default_context()
try:
    with smtplib.SMTP(smtp_server, smtp_port) as server:
        server.starttls(context=context)
        server.login(sender, password)
        server.sendmail(sender, receiver, msg.as_string())
    print("EMAIL_OK")
except Exception as exc:
    print("EMAIL_FAIL: {}".format(exc))
    sys.exit(2)
PY3EOF

    # check python exit status
    if [ $? -eq 0 ]; then
        log "Email sent to ${EMAIL_TO}"
    else
        log "Email send failed (see above python output)."
    fi
}

# ---------- Systemd service & hourly timer installation (permanent) ----------
install_systemd_unit() {
    log "Installing systemd service and hourly timer (permanent)."

    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}.timer"

    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Servant maintenance service (runs servant.sh)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/servant.sh run
Nice=10
EOF

    cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Servant hourly timer (checks preferred times and runs maintenance accordingly)

[Timer]
OnCalendar=*-*-* *:00:00
Persistent=true
AccuracySec=1m

[Install]
WantedBy=timers.target
EOF

    chmod 644 "$SERVICE_FILE" "$TIMER_FILE"
    systemctl daemon-reload
    systemctl enable --now "${SERVICE_NAME}.timer"
    log "Systemd timer ${SERVICE_NAME}.timer enabled and started."
}

# ---------- Self-install: copy to /usr/local/bin if not already ----------
self_install() {
    TARGET="/usr/local/bin/servant.sh"
    if [ "$(realpath "$0")" != "$TARGET" ]; then
        cp "$0" "$TARGET"
        chmod +x "$TARGET"
        log "Copied servant script to $TARGET"
    else
        log "Script already at $TARGET"
    fi
}

# ---------- Entry point ----------
case "$1" in
    run)
        # invoked by systemd timer or manual run to possibly perform maintenance
        if should_run_now ; then
            perform_maintenance
        else
            log "Servant: Not scheduled to run at this hour or already ran today. Exiting."
        fi
        ;;
    install)
        # one-time install: copy script, install systemd units
        self_install
        install_systemd_unit
        log "Servant installed. Timer active (hourly)."
        ;;
    uninstall)
        # remove systemd units and script (if desired)
        systemctl disable --now "${SERVICE_NAME}.timer" 2>/dev/null || true
        rm -f /etc/systemd/system/${SERVICE_NAME}.timer /etc/systemd/system/${SERVICE_NAME}.service
        systemctl daemon-reload
        log "Servant uninstalled (systemd units removed)."
        ;;
    *)
        # default behavior: ensure installed, then behave like 'install' (idempotent) and then attempt run-check
        self_install
        install_systemd_unit
        # run as the timer would (check if run needed)
        if should_run_now ; then
            perform_maintenance
        else
            log "Servant: Installed. Not running maintenance right now (next check hourly)."
        fi
        ;;
esac

# Exit animation
sleep 1
echo -ne "${YELLOW}Exiting"
for i in {1..4}; do echo -ne "."; sleep 0.5; done
echo -e "\n${GREEN}Goodbye, Master ... 🧠${NC}"
beep

