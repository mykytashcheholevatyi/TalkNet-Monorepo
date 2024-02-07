#!/bin/bash

# Установка строгого режима выполнения скрипта
set -Eeo pipefail

# Определение переменных для директорий и файлов
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$LOG_DIR/update-$DATE.log"

# Перенаправление вывода в лог-файл
exec > >(tee -a "$LOG_FILE") 2>&1

# Функция для обработки ошибок
error_exit() {
    echo "Произошла ошибка. См. лог: $LOG_FILE."
    # Если возникла ошибка во время миграции, пытаемся откатиться
    if [[ "$FLASK_MIGRATE" = true ]]; then
        flask db downgrade
    fi
    # Перезапуск приложения, чтобы оно продолжило работать после ошибки
    restart_application
    exit 1
}

trap 'error_exit' ERR

create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$DATE.sql"
    echo "Бэкап базы данных создан в $BACKUP_DIR/db_backup_$DATE.sql."
}

update_repository() {
    echo "Обновление кода из репозитория..."
    git -C "$APP_DIR" pull
    echo "Репозиторий обновлен."
}

activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    python -m ensurepip --upgrade
    echo "Виртуальное окружение активировано."
}

install_python_packages() {
    echo "Установка зависимостей Python..."
    pip install --upgrade pip
    pip install --upgrade -r "$APP_DIR/requirements.txt"
    echo "Зависимости Python установлены."
}

run_database_migration() {
    echo "Выполнение миграции базы данных..."
    export FLASK_APP=app.py
    export FLASK_ENV=production
    flask db upgrade
    FLASK_MIGRATE=true
    echo "Миграция базы данных выполнена."
}

rollback_database_migration() {
    echo "Откат изменений базы данных..."
    flask db downgrade
    echo "Миграция откачена."
}

restart_application() {
    echo "Перезапуск приложения..."
    # Убиваем текущие процессы gunicorn, если они есть
    pkill gunicorn || true
    # Запускаем приложение снова с использованием gunicorn
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon \
    --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

# Выполнение шагов обновления
create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
restart_application
deactivate_virtualenv

echo "Обновление успешно завершено: $DATE"
