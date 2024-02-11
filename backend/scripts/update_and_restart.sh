#!/bin/bash

set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

ENV_FILE="/srv/talknet/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Файл окружения $ENV_FILE не найден, завершение..."
    exit 1
fi

LOG_DIR="/srv/talknet/var/log"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
FLASK_APP_DIR="$APP_DIR/backend/auth-service"
VENV_DIR="$FLASK_APP_DIR/venv"

mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало развёртывания: $(date)"

rotate_logs() {
    find "$LOG_DIR" -type f -name '*.log' -mtime +30 -exec rm {} \;
    echo "Старые журналы удалены."
}

reinstall_postgresql_if_update_failed() {
    echo "Переустановка PostgreSQL при неудачном обновлении..."

    if ! sudo apt-get update && sudo apt-get upgrade -y postgresql postgresql-contrib; then
        echo "Не удалось обновить PostgreSQL, переустановка..."

        local installed_version=$(apt-cache policy postgresql | awk '/Installed/ {print $2}')
        if [ -z "$installed_version" ]; then
            echo "Ошибка: PostgreSQL не установлен."
            exit 1
        fi

        sudo apt-get remove --purge -y "postgresql-$installed_version" "postgresql-contrib-$installed_version"
        sudo rm -rf /var/lib/postgresql/

        sudo apt-get install -y "postgresql-$installed_version" "postgresql-contrib-$installed_version"
        echo "PostgreSQL переустановлен."
    else
        echo "Обновление PostgreSQL выполнено успешно."
    fi
}

init_db_cluster() {
    local version=$(apt-cache policy postgresql | awk '/Installed/ {print $2}')

    sudo pg_dropcluster --stop "$version" main || true
    sudo pg_createcluster "$version" main --start
    echo "Кластер PostgreSQL инициализирован."
}

configure_postgresql() {
    local version=$(pg_lsclusters | awk '/main/ {print $1}')

    sudo sed -i "/^#listen_addresses = 'localhost'/c\listen_addresses = '*'" "/etc/postgresql/$version/main/postgresql.conf"
    sudo sed -i "/^#port = 5432/c\port = 5432" "/etc/postgresql/$version/main/postgresql.conf"

    echo "host all all all md5" | sudo tee -a "/etc/postgresql/$version/main/pg_hba.conf"
    sudo systemctl restart postgresql
    echo "PostgreSQL настроен для приёма соединений."
}

create_db_user_and_database() {
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB TO $PG_USER;"
    echo "Пользователь и база данных созданы."
}

install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git nginx
    echo "Зависимости установлены."
}

test_db_connection() {
    if ! PGPASSWORD=$PG_PASSWORD psql -h localhost -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Соединение с базой данных не удалось."
        return 1
    else
        echo "Соединение с базой данных успешно установлено."
        return 0
    fi
}

apply_schema() {
    echo "Применение схемы базы данных..."
    SCHEMA_PATH="$FLASK_APP_DIR/database/schema.sql"
    if [ -f "$SCHEMA_PATH" ]; then
        sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH"
        echo "Схема применена из $SCHEMA_PATH."
    else
        echo "Файл схемы не найден по пути $SCHEMA_PATH. Проверьте путь и повторите попытку."
    fi
}

backup_db() {
    echo "Резервное копирование базы данных..."
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "База данных скопирована в $BACKUP_FILE."
}

clone_update_repo() {
    echo "Обновление репозитория..."
    if [ -d "$FLASK_APP_DIR/.git" ]; then
        cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard origin/main
    else
        git clone "$REPO_URL" "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    fi
    echo "Репозиторий обновлён."
}

setup_venv() {
    echo "Настройка виртуального окружения Python..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$FLASK_APP_DIR/requirements.txt"
    echo "Зависимости установлены."
}

apply_migrations() {
    echo "Применение миграций базы данных Flask..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$FLASK_APP_DIR/app.py"

    if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
        flask db init
    fi

    flask db migrate -m "Автоматически созданная миграция."
    flask db upgrade || echo "Нет миграций для применения или миграция завершилась неудачно."
}

restart_services() {
    echo "Перезапуск приложения Flask и Nginx..."
    pkill gunicorn || true
    cd "$FLASK_APP_DIR"
    gunicorn --bind 0.0.0.0:8000 "app:create_app()" --daemon
    sudo systemctl restart nginx
    echo "Приложение Flask и Nginx перезапущены."
}

rotate_logs
install_dependencies
reinstall_postgresql_if_update_failed
init_db_cluster
configure_postgresql
create_db_user_and_database
test_db_connection || { echo "Проблема с настройкой базы данных. Прерывание."; exit 1; }
backup_db
clone_update_repo
setup_venv
apply_schema
apply_migrations
restart_services

echo "Развёртывание завершено: $(date)"
