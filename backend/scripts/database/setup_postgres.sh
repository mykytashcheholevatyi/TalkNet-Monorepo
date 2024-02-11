#!/bin/bash

# Загрузка переменных окружения
source .env

# Строгий режим
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Функция для остановки существующего процесса PostgreSQL
function stop_existing_postgres() {
    echo "Проверка на существующие процессы PostgreSQL..."
    if lsof -i:5432; then
        echo "Обнаружен процесс, использующий порт 5432. Попытка остановить..."
        sudo systemctl stop postgresql || true
        echo "Ожидание освобождения порта 5432..."
        sleep 5
        if lsof -i:5432; then
            echo "Порт все еще занят. Принудительное завершение процесса..."
            sudo fuser -k 5432/tcp || true
        fi
    fi
    echo "Порт 5432 свободен."
}

# Функция для запуска PostgreSQL в Docker
function setup_postgres_docker() {
    echo "Запуск PostgreSQL в Docker..."
    docker run --name postgres -d \
        -e POSTGRES_DB="$PG_DB" \
        -e POSTGRES_USER="$PG_USER" \
        -e POSTGRES_PASSWORD="$PG_PASSWORD" \
        -p "$PG_PORT:5432" \
        postgres:"$PG_VERSION"
    echo "PostgreSQL запущен в Docker."
}

# Функция для применения обновлений схемы базы данных
function apply_schema_updates() {
    echo "Применение обновлений схемы базы данных..."
    # Здесь должна быть логика для применения обновлений схемы базы данных
    # Например, использование Flyway или Liquibase
    flyway migrate
    echo "Обновления схемы базы данных применены."
}

# Функция для настройки резервного копирования базы данных
function setup_backup() {
    echo "Настройка резервного копирования базы данных..."
    # Здесь должна быть логика для настройки резервного копирования
    # Например, настройка Barman или pgBackRest
    barman backup all
    echo "Резервное копирование настроено."
}

# Основная логика скрипта
stop_existing_postgres
setup_postgres_docker
apply_schema_updates
setup_backup

echo "Настройка и обновление PostgreSQL завершены."
