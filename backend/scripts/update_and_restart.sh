#!/bin/bash

# **Строгий режим:**
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# **Определение констант:**

# Версия PostgreSQL
readonly PG_VERSION="14"

# Настройки PostgreSQL
readonly PG_HOST="85.215.65.78"
readonly PG_PORT="5432"
readonly PG_DB="talknet_db"
readonly PG_USER="talknet_user"
readonly PG_PASSWORD="your_secure_password"

# Настройки репозитория
readonly REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo.git"
readonly REPO_BRANCH="main"

# Настройки приложения Flask
readonly FLASK_APP_DIR="/srv/talknet/backend/auth-service"
readonly FLASK_RUN_HOST="0.0.0.0"
readonly FLASK_RUN_PORT="8000"

# Настройки виртуального окружения Python
readonly VENV_DIR="$FLASK_APP_DIR/venv"

# Директории для логов и резервных копий
readonly LOG_DIR="/srv/talknet/var/log"
readonly BACKUP_DIR="/srv/talknet/backups"

# Настройки Gunicorn (если используется)
readonly GUNICORN_WORKERS="3"
readonly GUNICORN_BIND="0.0.0.0:8000"

# **Функции:**

# Ротация журналов
function rotate_logs() {
  find "$LOG_DIR" -type f -name "*.log" -mtime +30 -exec rm {} \;
  echo "Старые журналы очищены."
}

# Работа с PostgreSQL
function postgres() {
  local action="$1"
  case "$action" in
  "install")
    echo "Установка PostgreSQL..."
    sudo apt-get update
    sudo apt-get install -y "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"
    echo "PostgreSQL успешно установлен."
    ;;
  "init")
    echo "Инициализация кластера базы данных PostgreSQL..."
    sudo pg_dropcluster --stop $PG_VERSION main || true
    sudo pg_createcluster $PG_VERSION main --start
    echo "Кластер PostgreSQL инициализирован."
    ;;
  "configure")
    echo "Настройка PostgreSQL для приема подключений..."
    sudo sed -i "s|#listen_addresses = 'localhost'|listen_addresses = '*'" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    sudo sed -i "s|#port = 5432|port = 5432|" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
    echo "host all all 0.0.0.0/0 md5" | sudo tee -a "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
    echo "PostgreSQL настроен для приема подключений."
    ;;
  "restart")
    echo "Перезапуск PostgreSQL..."
    sudo systemctl restart postgresql
    echo "PostgreSQL перезапущен."
    ;;
  esac
}

# Работа с базой данных
function db() {
  local action="$1"
  case "$action" in
  "create-user")
    echo "Создание пользователя PostgreSQL..."
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    echo "Пользователь PostgreSQL создан."
    ;;
  "create-database")
    echo "Создание базы данных PostgreSQL..."
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
    echo "База данных PostgreSQL создана."
    ;;
  "backup")
    local backup_file="<span class="math-inline">BACKUP\_DIR/PG\_DB\_</span>(date +%Y-%m-%d_%H-%M-%S).sql"
    PGPASSWORD="$PG_PASSWORD" pg_dump -h "$PG_HOST" -U "$PG_USER" "$PG_DB" > "$backup_file"
    echo "База данных скопирована в $backup_file."
    ;;
  esac
}

# **Логика развертывания:**

# Очистка логов
rotate_logs

# Установка зависимостей
install_dependencies

# Работа с PostgreSQL
postgres install
postgres init
postgres configure

# Создание пользователя и базы данных
db create-user
db create-database

# Резервное копирование базы данных
db backup

# Тестирование подключения к базе данных
test_db_connection

# Применение схемы базы данных
apply_schema

# Обновление или клонирование репозитория
clone_update_repo

# Настройка виртуального окружения Python и установка зависимостей
setup_venv

# Применение миграций базы данных Flask
apply_migrations

# Перезапуск приложения Flask и Nginx
restart_services

# Вывод информации о завершении
echo "Развёртывание завершено: $(date)"
