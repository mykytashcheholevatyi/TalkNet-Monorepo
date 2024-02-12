#!/bin/bash

# Загрузка переменных окружения
if [ -f ".env" ]; then
    source .env
else
    echo ".env файл не найден."
    exit 1
fi

# Строгий режим
set -euo pipefail
IFS=$'\n\t'
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Установка Docker, если он еще не установлен
function install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Установка Docker..."
        sudo apt-get update
        sudo apt-get install -y docker.io
    else
        echo "Docker уже установлен."
    fi
}

# Остановка существующих контейнеров PostgreSQL
function stop_existing_postgres_containers() {
    echo "Остановка существующих контейнеров PostgreSQL..."
    if docker ps -a | grep -q postgres; then
        docker rm -f postgres || true
    fi
}

# Запуск PostgreSQL в Docker
function run_postgres_container() {
    echo "Запуск PostgreSQL в Docker..."
    docker run --name postgres -d \
        -e POSTGRES_DB="$PG_DB" \
        -e POSTGRES_USER="$PG_USER" \
        -e POSTGRES_PASSWORD="$PG_PASSWORD" \
        -p "$PG_PORT:5432" \
        -v postgres_data:/var/lib/postgresql/data \
        postgres:"$PG_VERSION"
    echo "PostgreSQL запущен в контейнере с именем 'postgres'."
}

# Клонирование репозитория и применение схемы базы данных
function clone_repo_and_apply_schema() {
    TMP_DIR=$(mktemp -d)
    echo "Клонирование репозитория в $TMP_DIR..."
    git clone "$REPO_URL" "$TMP_DIR" --branch "$REPO_BRANCH"
    
    SCHEMA_FILE="$TMP_DIR/$SCHEMA_PATH"
    if [ -f "$SCHEMA_FILE" ]; then
        echo "Применение схемы базы данных из $SCHEMA_FILE..."
        docker cp "$SCHEMA_FILE" postgres:/schema.sql
        docker exec postgres psql -U "$PG_USER" -d "$PG_DB" -f /schema.sql
        echo "Схема базы данных успешно применена."
    else
        echo "Файл схемы не найден: $SCHEMA_FILE"
    fi

    rm -rf "$TMP_DIR"
    echo "Временный каталог $TMP_DIR удален."
}

# Основная логика скрипта
install_docker
stop_existing_postgres_containers
run_postgres_container
clone_repo_and_apply_schema

echo "Настройка базы данных завершена."
