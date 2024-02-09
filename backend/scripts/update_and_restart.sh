#!/bin/bash

# Strikte obsługa błędów i wyjście w przypadku napotkania niezdefiniowanych zmiennych
set -euo pipefail
trap 'echo "Wystąpił błąd w linii $LINENO. Wyjście z kodem błędu $?" >&2' ERR

# Definicja ścieżek i plików logowania
LOG_DIR="/srv/talknet/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Rozpoczęcie wykonania skryptu: $(date)"

# Funkcja logowania
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Instalacja wymaganych pakietów
install_dependencies() {
    log_message "Instalacja wymaganych pakietów..."
    DEPS="python3 python3-pip python3-venv git postgresql postgresql-contrib nginx"
    for dep in $DEPS; do
        if ! dpkg -l | grep -qw $dep; then
            log_message "Instalacja $dep..."
            sudo apt-get install -y $dep
        else
            log_message "$dep jest już zainstalowany."
        fi
    done
}

# Konfiguracja PostgreSQL
setup_postgresql() {
    PG_USER="your_username"
    PG_DB="prod_db"
    PG_PASSWORD="your_password"
    log_message "Konfiguracja PostgreSQL..."
    sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1 || sudo -u postgres createuser -P "$PG_USER"
    sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || sudo -u postgres createdb -O "$PG_USER" "$PG_DB"
}

# Klonowanie lub aktualizacja repozytorium
clone_or_update_repository() {
    REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
    APP_DIR="/srv/talknet"
    log_message "Klonowanie lub aktualizacja repozytorium..."
    if [ ! -d "$APP_DIR" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR"
        git fetch origin
        git reset --hard origin/main
        git clean -fdx
    fi
}

# Konfiguracja środowiska Python i instalacja zależności
setup_python_environment() {
    VENV_DIR="$APP_DIR/backend/auth-service/venv"
    log_message "Konfiguracja środowiska Python..."
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    log_message "Instalacja zależności Python..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Tworzenie kopii zapasowej bazy danych
backup_database() {
    BACKUP_DIR="/srv/talknet/backups"
    mkdir -p "$BACKUP_DIR"
    log_message "Tworzenie kopii zapasowej bazy danych..."
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
}

# Przesyłanie zmian do repozytorium
push_to_repository() {
    log_message "Przesyłanie zmian do repozytorium..."
    cd "$APP_DIR"
    git add .
    git commit -m "Automatyczna kopia zapasowa bazy danych: $(date)"
    git push -f origin main
    log_message "Zmiany przesłane do repozytorium."
}

# Uruchamianie aplikacji Flask
start_flask_application() {
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    log_message "Uruchamianie aplikacji Flask..."
    pkill gunicorn || true  # Zabija gunicorn jeśli działa
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    log_message "Aplikacja Flask uruchomiona."
}

# Sprawdzanie stanu aplikacji
check_application_status() {
    log_message "Sprawdzanie stanu aplikacji..."
    if curl -s "http://localhost:8000" | grep -q "200 OK"; then
        log_message "Aplikacja działa poprawnie."
    else
        log_message "Aplikacja nie odpowiada. Sprawdź logi."
        exit 1
    fi
}

# Oczyszczanie starych kopii zapasowych
cleanup_old_backups() {
    log_message "Oczyszczanie starych kopii zapasowych..."
    find "$BACKUP_DIR" -type f -mtime +30 -name '*.sql' -exec rm {} \;
    log_message "Stare kopie zapasowe usunięte."
}

# Weryfikacja konfiguracji nginx
verify_nginx_configuration() {
    log_message "Weryfikacja konfiguracji nginx..."
    if nginx -t; then
        log_message "Konfiguracja nginx jest poprawna."
    else
        log_message "Błąd konfiguracji nginx. Proszę sprawdzić."
        exit 1
    fi
}

# Restart nginx
restart_nginx() {
    log_message "Restart nginx..."
    sudo systemctl restart nginx
    log_message "nginx zrestartowany."
}

# Główna sekwencja wykonania
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database
push_to_repository
start_flask_application
check_application_status
cleanup_old_backups
verify_nginx_configuration
restart_nginx

log_message "Wykonanie skryptu zakończone sukcesem: $(date)"
