#!/bin/bash

# Инициализация и строгий режим
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Загрузка переменных окружения
ENV_FILE="/srv/talknet/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Файл окружения $ENV_FILE не найден, завершение..."
    exit 1
fi

# Пути к каталогам
LOG_DIR="/srv/talknet/var/log"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
FLASK_APP_DIR="$APP_DIR/backend/auth-service"
VENV_DIR="$FLASK_APP_DIR/venv"

# Проверка существования каталогов
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"

# Настройка файла журнала
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало развёртывания: $(date)"

# Поворот журналов
rotate_logs() {
    find "$LOG_DIR" -type f -name '*.log' -mtime +30 -exec rm {} \;
    echo "Старые журналы удалены."
}

# Переустановка PostgreSQL при неудачном обновлении
reinstall_postgresql_if_update_failed() {
    echo "Переустановка PostgreSQL при неудачном обновлении..."

    # Попытка обновления PostgreSQL
    if ! sudo apt-get update && sudo apt-get upgrade -y postgresql postgresql-contrib; then
        echo "Не удалось обновить PostgreSQL, переустановка..."

        # Попытка переустановки PostgreSQL
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

# Инициализация кластера базы данных PostgreSQL
init_db_cluster() {
    local version=$(apt-cache policy postgresql | awk '/Installed/ {print $2}')

    # Инициализация кластера PostgreSQL с указанной версией
    sudo pg_dropcluster --stop "$version" main || true  # Удаление существующего кластера, если есть
    sudo pg_createcluster "$version" main --start  # Создание нового кластера
    echo "Кластер PostgreSQL инициализирован."
}

# Настройка PostgreSQL для приёма соединений
configure_postgresql() {
    local version=$(pg_lsclusters | awk '/main/ {print $1}')
    # Замена параметров listen_addresses и port в postgresql.conf
    sudo sed -i "/^#listen_addresses = 'localhost'/c\listen_addresses = '*'" "/etc/postgresql/$version/main/postgresql.conf"
    sudo sed -i "/^#port = 5432/c\port = 5432" "/etc/postgresql/$version/main/postgresql.conf"

    # Разрешение всех соединений в pg_hba.conf
    echo "host all all all md5" | sudo tee -a "/etc/postgresql/$version/main/pg_hba.conf"
    sudo systemctl restart postgresql
    echo "PostgreSQL настроен для приёма соединений."
}

# Создание пользователя и базы данных PostgreSQL
create_db_user_and_database() {
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB TO $PG_USER;"
    echo "Пользователь и база данных созданы."
}

# Установка необходимых зависимостей
install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git nginx
    echo "Зависимости установлены."
}

# Проверка соединения с базой данных
test_db_connection() {
    if ! PGPASSWORD=$PG_PASSWORD psql -h localhost -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Соединение с базой данных не удалось."
        return 1
    else
        echo "Соединение с базой данных успешно установлено."
        return 0
    fi
}

# Применение схемы базы данных
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

# Резервное копирование базы данных
backup_db() {
    echo "Резервное копирование базы данных..."
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "База данных скопирована в $BACKUP_FILE."
}

# Обновление или клонирование репозитория
clone_update_repo() {
    echo "Обновление репозитория..."
    if [ -d "$FLASK_APP_DIR/.git" ]; then
        cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard origin/main
    else
        git clone "$REPO_URL" "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    fi
    echo "Репозиторий обновлён."
}

# Настройка виртуального окружения Python и установка зависимостей
setup_venv() {
    echo "Настройка виртуального окружения Python..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$FLASK_APP_DIR/requirements.txt"
    echo "Зависимости установлены."
}

# Применение миграций базы данных Flask
apply_migrations() {
    echo "Применение миграций базы данных Flask..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$FLASK_APP_DIR/app.py"  # Измените на точку входа вашего приложения Flask

    if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
        flask db init
    fi

    flask db migrate -m "Автоматически созданная миграция."
    flask db upgrade || echo "Нет миграций для применения или миграция завершилась неудачно."
}

# Перезапуск приложения Flask и Nginx
restart_services() {
    echo "Перезапуск приложения Flask и Nginx..."
    # Замените на фактические команды для перезапуска Flask и Nginx
    pkill gunicorn || true
    cd "$FLASK_APP_DIR"
    gunicorn --bind 0.0.0.0:8000 "app:create_app()" --daemon
    sudo systemctl restart nginx
    echo "Приложение Flask и Nginx перезапущены."
}

# Основная логика
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
