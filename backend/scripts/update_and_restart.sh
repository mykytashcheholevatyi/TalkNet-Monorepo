#!/bin/bash

# Настроить прерывание при ошибках и ловить их
set -Eeo pipefail

echo "Начало обновления: $(date)"

# Конфигурация
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"

# Перенаправить вывод в лог файл
exec > >(tee -a "$LOG_FILE") 2>&1

# Обработчик ошибок
error_exit() {
    echo "Произошла критическая ошибка."
    echo "Попытка откатить миграцию и перезапустить приложение..."
    flask db downgrade
    restart_application
    exit 1
}

trap 'error_exit' ERR

create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
    echo "Бэкап базы данных создан."
}

update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR"
    git pull origin main
    echo "Репозиторий обновлен."
}

activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Виртуальное окружение активировано."
}

install_python_packages() {
    echo "Установка зависимостей..."
    pip install --upgrade pip
    pip install --upgrade -r "$APP_DIR/requirements.txt"
    echo "Зависимости установлены."
}

run_database_migration() {
    echo "Выполнение миграции базы данных..."
    export FLASK_APP=app.py
    export FLASK_ENV=production
    flask db upgrade
    echo "База данных мигрирована."
}

rollback_database_migration() {
    echo "Откат миграции базы данных..."
    flask db downgrade
    echo "Миграция откачена."
}

restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

# Последовательное выполнение функций
create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
restart_application

echo "Обновление успешно завершено: $(date)"
