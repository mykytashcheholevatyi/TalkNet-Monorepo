#!/bin/bash

set -Eeo pipefail

APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$LOG_DIR/update-$DATE.log"

exec > >(tee -a "$LOG_FILE") 2>&1

trap 'error_exit' ERR

error_exit() {
    echo "Произошла ошибка. См. лог: $LOG_FILE."
    if [[ "$FLASK_MIGRATE" = true ]]; then
        flask db downgrade
    fi
    restart_application
    exit 1
}

create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$DATE.sql" 2>>"$LOG_FILE" || {
        echo "Ошибка при создании бэкапа базы данных."
        return 1 # Возвращаем статус ошибки для обработчика trap
    }
    echo "Бэкап базы данных создан."
}

update_repository() {
    echo "Обновление репозитория..."
    git -C "$APP_DIR" pull origin main || {
        echo "Ошибка при обновлении репозитория."
        return 1
    }
    echo "Репозиторий обновлен."
}

activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if ! source "$VENV_DIR/bin/activate"; then
        echo "Ошибка активации виртуального окружения."
        return 1
    fi
    echo "Виртуальное окружение активировано."
}

install_python_packages() {
    echo "Установка зависимостей..."
    pip3 install --upgrade pip
    pip3 install --upgrade -r "$APP_DIR/requirements.txt" || {
        echo "Ошибка при установке зависимостей."
        return 1
    }
    echo "Зависимости установлены."
}

run_database_migration() {
    echo "Миграция базы данных..."
    FLASK_APP=app.py FLASK_ENV=production flask db upgrade || {
        echo "Ошибка миграции базы данных."
        FLASK_MIGRATE=true
        return 1
    }
    echo "Миграция базы данных выполнена."
}

restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon \
    --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log" || {
        echo "Ошибка при перезапуске приложения."
        return 1
    }
    echo "Приложение перезапущено."
}

# Выполнение шагов обновления
create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
restart_application

echo "Обновление успешно завершено: $DATE"
