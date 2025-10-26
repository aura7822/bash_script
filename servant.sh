#!/bin/bash
# 🧠 Servant.sh — Animated Maintenance Daemon Edition (Aura™)
# by Aura | Animated, Monochrome, Cinematic Version

clear

# === Banner Animation ===
banner_lines=(
"   ◯ ▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩ ◯"
"   ▨                                                                                         ▨ "
"   ▨        ███████╗  ███████╗  ██████╗   ██╗   ██╗   █████╗   ███╗   ██╗ █████████╗TM       ▨ "
"   ▨        ██╔════╝  ██╔════╝  ██╔══██╗  ██║   ██║  ██╔══██╗  ████╗  ██║     ██╔═╝          ▨ "
"   ▨        ███████╗  █████╗    ██████╔╝  ██║   ██║  ███████║  ██╔██╗ ██║     ██╗            ▨ "
"   ▨        ╚════██║  ██╔══╝    ██╔══██╗  ██║   ██║  ██╔══██║  ██║╚██╗██║     ██║            ▨ "
"   ▨        ███████║  ███████╗  ██║  ██║ ╚  ████ ╔╝  ██║  ██║  ██║ ╚████║     ██║            ▨ "
"   ▨        ╚══════╝  ╚══════╝  ╚═╝  ╚═╝   ╚═════╝    ═╝  ╚═╝  ╚═╝  ╚═══╝    ╚══╝            ▨ "
"   ▨                                                                                         ▨ "
"   ▨                        🧠 SYSTEM SERVANT DAEMON — UTILITY EDITION®                      ▨ "
"   ◯ ▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩▩ ◯"
)

for line in "${banner_lines[@]}"; do
    echo "$line"
    sleep 0.07
done

sleep 1
echo -e "\n🔍 Detecting system type...\n"
sleep 1

# === System Detection ===
if [ -f /etc/fedora-release ]; then
    system="Fedora"
elif [ -f /etc/arch-release ]; then
    system="Arch"
elif [ -f /etc/debian_version ]; then
    system="Debian/Ubuntu"
else
    system="Unknown"
fi
echo "✅ Detected: $system"
sleep 1

# === Spinner Setup ===
spinner="/-\|"
i=0

# === Periodic Bell in Background ===
(
  while true; do
    echo -en "\a"
    sleep 6
  done
) & BELL_PID=$!

# === Maintenance Process ===
echo -ne "\n⚙️  Performing maintenance... "
sleep 1

animate_spinner() {
  while ps -p $1 > /dev/null; do
    printf "\b${spinner:i++%${#spinner}:1}"
    sleep 0.1
  done
}

# Run actual system update in background (simulate if not sudo)
case $system in
  "Debian/Ubuntu")
    (sudo apt update -y && sudo apt upgrade -y && sudo apt autoremove -y && sudo apt autoclean -y) & PROC=$!
    ;;
  "Fedora")
    (sudo dnf upgrade -y && sudo dnf autoremove -y && sudo dnf clean all) & PROC=$!
    ;;
  "Arch")
    (sudo pacman -Syu --noconfirm && sudo pacman -Rns $(pacman -Qdtq) --noconfirm && sudo pacman -Sc --noconfirm) & PROC=$!
    ;;
  *)
    (sleep 5) & PROC=$!
    ;;
esac

animate_spinner $PROC
wait $PROC
kill $BELL_PID &>/dev/null

# === Cleanup Animation ===
echo -e "\b✅ Done!\n"
sleep 0.7
echo "🧹 Cleaning up..."
sleep 2
echo -e "\a"
sleep 1
clear

# === Closing Animation ===
echo ""
msg1="           Mission Complete, Master 🧠"
msg2="         System integrity restored."
for ((j=0; j<${#msg1}; j++)); do
    printf "%s" "${msg1:$j:1}"
    sleep 0.04
done
echo ""
for ((j=0; j<${#msg2}; j++)); do
    printf "%s" "${msg2:$j:1}"
    sleep 0.04
done
echo -e "\n"
sleep 1.5
echo -e "\a"
echo ""
exit 0
