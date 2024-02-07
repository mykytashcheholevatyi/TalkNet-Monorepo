#!/bin/bash

set -e

echo "Начало обновления: $(date)"

APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"

# Функция для создания бэкапа базы данных
create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    if sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"; then
        echo "Бэкап базы данных создан успешно."
    else
        echo "Ошибка при создании бэкапа базы данных. Процесс остановлен."
        exit 1
    fi
}

# Функция для обновления репозитория из Git
update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR"
    if git pull; then
        echo "Репозиторий успешно обновлен."
    else
        echo "Ошибка при обновлении репозитория. Процесс остановлен."
        exit 1
    fi
}

# Функция для активации виртуального окружения
activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if [ -d "$VENV_DIR" ]; then
        . "$VENV_DIR/bin/activate"
    else
        echo "Виртуальное окружение не найдено. Создание нового виртуального окружения..."
        python3 -m venv "$VENV_DIR"
        . "$VENV_DIR/bin/activate"
        echo "Виртуальное окружение создано."
        python -m ensurepip --upgrade
    fi
}

# Функция для установки пакетов Python
install_python_packages() {
    echo "Установка пакетов Python..."
    if pip install flask_login && pip install --upgrade -r "$APP_DIR/requirements.txt"; then
        echo "Зависимости Python успешно обновлены."
    else
        echo "Ошибка при обновлении зависимостей Python. Процесс остановлен."
        deactivate
        exit 1
    fi
}

# Функция для выполнения миграции базы данных
run_database_migration() {
    echo "Миграция базы данных..."
    export FLASK_APP=app.py
    export FLASK_ENV=production

    if [ ! -d "$APP_DIR/migrations" ]; then
        flask db init
        echo "Миграционный репозиторий инициализирован."
    fi

    if ! flask db migrate -m "New migration"; then
        rollback_database_migration
        return
    fi

    if flask db upgrade; then
        echo "Миграция базы данных выполнена успешно."
    else
        echo "Ошибка при миграции базы данных. Процесс остановлен."
        rollback_database_migration
    fi
}

# Функция для сброса миграции базы данных в случае ошибки
rollback_database_migration() {
    echo "Сброс миграции базы данных..."
    if flask db downgrade base; then
        echo "Миграция базы данных отменена. Пожалуйста, проверьте миграционные скрипты."
    else
        echo "Ошибка при отмене миграций. Требуется вмешательство."
    fi
    deactivate
    exit 1
}

# Функция для деактивации виртуального окружения
deactivate_virtualenv() {
    echo "Деактивация виртуального окружения..."
    deactivate
}

# Функция для перезапуска приложения через Gunicorn
restart_application() {
    echo "Перезапуск приложения через Gunicorn..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение успешно обновлено и перезапущено."
}

# Основной скрипт
create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
deactivate_virtualenv
restart_application
