#!/bin/bash

# Установка строгого режима: немедленное прекращение при ошибках, перенаправление в лог
set -Eeo pipefail
LOG_FILE="/var/log/talknet/update-$(date +%Y-%m-%d_%H-%M-%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Обработчик ошибок, запускаемый при любой ошибке
error_exit() {
    echo "Произошла ошибка. Проверьте лог файл для получения дополнительной информации."
    flask db downgrade
    restart_application
    exit 1
}

trap 'error_exit' ERR

# Переменные
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"

# Функции
create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
    echo "Бэкап базы данных создан."
}

update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR" || exit
    git pull origin main
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
    echo "Установка пакетов Python..."
    pip install --upgrade pip
    pip install --upgrade -r "$APP_DIR/requirements.txt"
    echo "Зависимости Python успешно обновлены."
}

run_database_migration() {
    echo "Выполнение миграции базы данных..."
    export FLASK_APP=app.py
    export FLASK_ENV=production
    flask db upgrade
    echo "Миграция базы данных выполнена."
}

rollback_database_migration() {
    echo "Откат миграции базы данных..."
    flask db downgrade
    echo "Миграция базы данных откачена."
}

deactivate_virtualenv() {
    echo "Деактивация виртуального окружения..."
    deactivate
}

restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true # Игнорировать ошибки, если gunicorn не запущен
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon \
    --log-file="/var/log/talknet/gunicorn.log" --access-logfile="/var/log/talknet/access.log"
    echo "Приложение перезапущено."
}

# Основная логика
create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
restart_application
deactivate_virtualenv

echo "Обновление успешно завершено: $(date)"
