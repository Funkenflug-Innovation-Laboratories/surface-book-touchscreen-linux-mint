#!/bin/bash
#
# Auto_Install_Touchscreen.sh
# Automatisiertes Skript zur Installation des Touchscreens auf Microsoft Surface Book Gen 1 unter Linux Mint
# Entwickelt von Funkenflug Innovation Laboratories
# Lizenz: MIT License
#
# Dieses Skript installiert:
# - linux-surface-Kernel
# - iptsd und libwacom-surface
# - Passt GRUB an und lädt notwendige Kernel-Module
# - Prüft die Installation und erstellt eine Zusammenfassung
#
# VORSICHT:
# - Das Skript benötigt Root-Rechte.
# - Es wird empfohlen, vorher ein Timeshift-Snapshot zu erstellen.

# --- Farben für die Ausgabe ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Funktionen ---
function echo_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

function check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo_error "Dieses Skript muss als Root ausgeführt werden. Bitte verwenden Sie 'sudo'."
    fi
}

function install_dependencies() {
    echo_info "Installiere benötigte Abhängigkeiten..."
    apt update && apt install -y wget gnupg2
    if [ $? -ne 0 ]; then
        echo_error "Fehler beim Installieren der Abhängigkeiten."
    fi
}

function setup_surface_repository() {
    echo_info "Richte Surface-Repository ein..."
    wget -qO - https://raw.githubusercontent.com/linux-surface/linux-surface/master/pkg/keys/surface.asc \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/linux-surface.gpg

    echo "deb [arch=amd64] https://pkg.surfacelinux.com/debian release main" \
        | tee /etc/apt/sources.list.d/linux-surface.list > /dev/null

    apt update
    if [ $? -ne 0 ]; then
        echo_error "Fehler beim Einrichten des Surface-Repositorys."
    fi
}

function install_surface_kernel() {
    echo_info "Installiere Surface-Kernel und Pakete..."
    apt install -y linux-image-surface linux-headers-surface libwacom-surface iptsd linux-surface-secureboot-mok
    if [ $? -ne 0 ]; then
        echo_error "Fehler beim Installieren des Surface-Kernels."
    fi
}

function backup_grub() {
    echo_info "Erstelle Backup der GRUB-Konfiguration..."
    cp /etc/default/grub /etc/default/grub.backup
}

function modify_grub() {
    echo_info "Passe GRUB an für bessere Touchscreen-Unterstützung..."
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash i8042.nokbd=1"/' /etc/default/grub
    update-grub
    if [ $? -ne 0 ]; then
        echo_error "Fehler beim Aktualisieren von GRUB."
    fi
}

function load_kernel_modules() {
    echo_info "Lade notwendige Kernel-Module..."
    modprobe i2c_hid
    modprobe hid_multitouch
    modprobe hid_elan
}

function check_installation() {
    echo_info "Prüfe Installation..."

    # Prüfe, ob der Surface-Kernel läuft
    if ! uname -a | grep -q "surface"; then
        echo_warning "Der Surface-Kernel läuft nicht. Bitte starte das System neu und wähle im GRUB-Menü den Surface-Kernel aus."
    fi

    # Prüfe, ob der Touchscreen erkannt wird
    if ! libinput list-devices | grep -q "IPTS"; then
        echo_warning "Der Touchscreen wird nicht als IPTS-Gerät erkannt. Prüfe die Logs mit 'dmesg | grep -i touch'."
    fi

    # Prüfe, ob iptsd läuft
    if ! systemctl is-active --quiet iptsd; then
        echo_warning "iptsd läuft nicht. Starte es manuell mit 'sudo systemctl start iptsd@...' (ersetze ... mit der richtigen Instanz)."
    fi

    echo_success "Prüfung abgeschlossen. Überprüfe die Ausgabe oben für Warnungen oder Fehler."
}

function print_summary() {
    echo_info "Zusammenfassung der Installation:"
    echo "--------------------------------"
    echo "1. Surface-Repository: $(if [ -f /etc/apt/sources.list.d/linux-surface.list ]; then echo_success 'Eingerichtet'; else echo_error 'Nicht eingerichtet'; fi)"
    echo "2. Surface-Kernel: $(if dpkg -l | grep -q linux-image-surface; then echo_success 'Installiert'; else echo_error 'Nicht installiert'; fi)"
    echo "3. iptsd: $(if dpkg -l | grep -q iptsd; then echo_success 'Installiert'; else echo_error 'Nicht installiert'; fi)"
    echo "4. libwacom-surface: $(if dpkg -l | grep -q libwacom-surface; then echo_success 'Installiert'; else echo_error 'Nicht installiert'; fi)"
    echo "5. GRUB angepasst: $(if grep -q "i8042.nokbd=1" /etc/default/grub; then echo_success 'Ja'; else echo_error 'Nein'; fi)"
    echo "6. Kernel-Module geladen: $(if lsmod | grep -q "i2c_hid"; then echo_success 'Ja'; else echo_error 'Nein'; fi)"
    echo "--------------------------------"
}

# --- Hauptskript ---
echo_info "Starte Auto_Install_Touchscreen.sh für Microsoft Surface Book Gen 1 unter Linux Mint..."

check_root

install_dependencies
setup_surface_repository
backup_grub
install_surface_kernel
modify_grub
load_kernel_modules
check_installation
print_summary

echo_success "Skript abgeschlossen! Bitte starte das System neu und prüfe den Touchscreen mit 'xinput list' oder 'libinput list-devices'."
echo_info "Falls Probleme auftreten, prüfe die Logs mit 'dmesg | grep -i touch' oder 'journalctl -b | grep -Ei \"ipts|touch|stylus\"'."