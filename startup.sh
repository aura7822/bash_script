#!/bin/bash
clear

# --- Color Codes ---
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RESET="\e[0m"

# --- Typing Animation ---
type_text() {
    text="$1"
    delay=${2:-0.05}
    for (( i=0; i<${#text}; i++ )); do
        echo -ne "${text:$i:1}"
        sleep $delay
    done
    echo ""
}

# --- Animated Boot Bar ---
boot_bar() {
    label="$1"
    color="$2"
    echo -ne "${color}${label}:${RESET} "
    for i in {1..30}; do
        echo -ne "${color}▩${RESET}"
        sleep 0.05
    done
    echo -e " ${RED}[POSITIVE]${RESET}"
    sleep 0.2
}

# --- Matrix Burst ---
matrix_burst() {
    tput civis
    lines=$(tput lines)
    cols=$(tput cols)
    duration=3
    end=$((SECONDS+duration))
    while [ $SECONDS -lt $end ]; do
        rand_col=$((RANDOM % cols))
        rand_line=$((RANDOM % lines))
        rand_char=$(echo $((RANDOM % 2)))
        echo -ne "\e[${rand_line};${rand_col}H${RED}${rand_char}${RESET}"
        sleep 0.002
    done
    tput cnorm
    clear
}


# --- Play Sound ---
play_beep() {
    # Uses the system bell if available
    echo -ne "\007"
}

# --- Boot Sequence Start ---
clear
matrix_burst

echo -e "${GREEN}"
type_text "Starting system processes..."
sleep 0.1
boot_bar "Boot sequence initializing" "${MAGENTA}"
sleep 0.1
type_text "Initializing core modules..."
boot_bar "Core modules loading" "${MAGENTA}"
sleep 0.1
type_text "Calibrating terminal environment..."
boot_bar "Terminal environment setup" "${RED}"
sleep 0.2
echo -e "${CYAN}"
type_text "Initializing system..."
sleep 0.2
echo -e "${MAGENTA}"
type_text "Welcome back, A u r a ™"
sleep 0.3
echo -e "${RESET}"
#---RAINBOW ASCII---
figlet "a u r a . f e d o r a" | lolcat
sleep 0.3
echo -e "${MAGENTA}"
type_text "System live !... All modules operational."
play_beep
echo -e "${RESET}"

