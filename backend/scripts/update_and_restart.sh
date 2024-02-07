#!/bin/bash

set -euo pipefail
trap 'echo "Error: Script failed." ; exit 1' ERR

echo "Начало полной очистки, обновления и восстановления проекта: $(date)"

# Конфигурация
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
REQS_FILE="requirements.txt"
APP_FILE="app.py"
PG_DB="prod_db"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"

# Создание директории для логов и бэкапа
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

backup_database() {
    echo "Создание бэкапа базы данных..."
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
}

cleanup() {
    echo "Очистка текущей установки..."
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

clone_and_setup() {
    echo "Клонирование репозитория и установка зависимостей..."
    git clone "$REPO_URL" "$APP_DIR" --single-branch
    cd "$APP_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$REQS_FILE"
}

apply_migrations() {
    echo "Применение миграций базы данных..."
    export FLASK_APP="$APP_FILE"
    export FLASK_ENV=production
    flask db upgrade
}

restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 "app:app" --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

# Шаги скрипта
backup_database
cleanup
clone_and_setup
apply_migrations
restart_application

echo "Обновление успешно завершено: $(date)"
