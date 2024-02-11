#!/bin/bash

# Установка строгого режима выполнения, обработка ошибок и отслеживаемость
set -euo pipefail
trap 'echo "Произошла ошибка на строке $LINENO. Выход с кодом ошибки $?" >&2; exit 1' ERR

# Загрузка переменных окружения
if [ -f /srv/talknet/.env ]; then
    source /srv/talknet/.env
fi

# Определение путей к директориям
LOG_DIR="/srv/talknet/var/log"
STATS_DIR="/srv/talknet/var/stats"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
VENV_DIR="$APP_DIR/backend/auth-service/venv"
SCHEMA_PATH="$APP_DIR/backend/auth-service/database/forum_schema.sql"

# Создание необходимых директорий
mkdir -p "$LOG_DIR" "$STATS_DIR" "$BACKUP_DIR"

# Перенаправление stdout и stderr в файл журнала
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Начало выполнения скрипта: $(date)"

# Функция для ротации логов Flask
rotate_flask_logs() {
    echo "Ротация и архивация старых логов Flask..."
    find "$LOG_DIR" -name 'flask_app*.log' -mtime +30 -exec rm {} \;
}

# Функция для установки зависимостей
install_dependencies() {
    echo "Установка необходимых пакетов..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git postgresql postgresql-contrib nginx
}

# Функция для настройки PostgreSQL
setup_postgresql() {
    echo "Настройка пользователя и базы данных PostgreSQL..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $PG_DB;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $PG_USER;"
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"
    sudo -u postgres psql -d "$PG_DB" -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
    sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH" || echo "Внимание: Проблема при применении схемы базы данных."
}

# Функция для клонирования или обновления репозитория
clone_or_update_repository() {
    echo "Клонирование или обновление репозитория..."
    if [ ! -d "$APP_DIR/.git" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR" && git stash && git pull --rebase && git stash pop || true
    fi
}

# Функция для настройки Python окружения
setup_python_environment() {
    echo "Настройка виртуального окружения Python и установка зависимостей..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Функция для создания резервной копии базы данных и сбора статистики
backup_database_and_collect_stats() {
    echo "Создание резервной копии базы данных и сбор статистики..."
    BACKUP_FILE="$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    STATS_FILE="$STATS_DIR/deploy_stats_$(date +%Y-%m-%d_%H-%M-%S).log"
    top -b -n 1 >> "$STATS_FILE"
    df -h >> "$STATS_FILE"
    free -m >> "$STATS_FILE"
}

# Функция для применения миграций базы данных
apply_database_migrations() {
    echo "Применение миграций базы данных..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    flask db upgrade || echo "Внимание: Не удалось применить миграции базы данных."
}

# Функция для отправки изменений в репозиторий
push_to_repository() {
    echo "Проверка изменений и отправка в репозиторий..."
    cd "$APP_DIR"
    if git status --porcelain | grep -v "^??"; then
        git add .
        git commit -m "Автоматический бэкап базы данных: $(date)"
        git push origin main
        echo "Изменения отправлены в репозиторий."
    else
        echo "Нет значимых изменений для отправки."
    fi
}

# Функция для запуска Flask приложения
start_flask_application() {
    echo "Запуск Flask приложения..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Flask приложение запущено."
}

# Основная последовательность выполнения
rotate_flask_logs
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database_and_collect_stats
apply_database_migrations
push_to_repository
start_flask_application

echo "Выполнение скрипта завершено: $(date)"
