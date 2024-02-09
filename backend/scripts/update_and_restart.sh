#!/bin/bash

# Установка строгого режима выполнения и обработки ошибок
set -euo pipefail
trap 'echo "Произошла ошибка на строке $LINENO. Выход с кодом ошибки $?" >&2' ERR

# Определение переменных конфигурации
LOG_DIR="/srv/talknet/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало выполнения скрипта: $(date)"

# Установка необходимых пакетов
install_dependencies() {
    echo "Установка необходимых пакетов..."
    DEPS="python3 python3-pip python3-venv git postgresql postgresql-contrib nginx"
    for dep in $DEPS; do
        if ! dpkg -l | grep -qw $dep; then
            echo "Установка $dep..."
            sudo apt-get install -y $dep
        else
            echo "$dep уже установлен."
        fi
    done
}

# Настройка PostgreSQL
setup_postgresql() {
    PG_USER="your_username"
    PG_DB="prod_db"
    PG_PASSWORD="your_password"
    echo "Настройка PostgreSQL..."
    sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1 || sudo -u postgres createuser -P "$PG_USER"
    sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || sudo -u postgres createdb -O "$PG_USER" "$PG_DB"
}

# Клонирование или обновление репозитория
clone_or_update_repository() {
    REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
    APP_DIR="/srv/talknet"
    echo "Клонирование или обновление репозитория..."
    if [ ! -d "$APP_DIR" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR"
        git reset --hard  # Сброс всех изменений
        git clean -fd  # Удаление неотслеживаемых файлов и директорий
        git pull -f  # Принудительное обновление
    fi
}

# Настройка Python виртуального окружения и установка зависимостей
setup_python_environment() {
    VENV_DIR="$APP_DIR/backend/auth-service/venv"
    echo "Настройка Python окружения..."
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Установка Python зависимостей..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Резервное копирование базы данных
backup_database() {
    BACKUP_DIR="/srv/talknet/backups"
    mkdir -p "$BACKUP_DIR"
    echo "Создание резервной копии базы данных..."
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
}

# Пуш изменений в репозиторий
push_to_repository() {
    echo "Пуш изменений в репозиторий..."
    cd "$APP_DIR"
    git add .
    git commit -m "Автоматическое резервное копирование базы данных: $(date)"
    git push origin main  # Замените 'main' на название вашей ветки, если оно отличается
    echo "Изменения отправлены в репозиторий."
}

# Запуск Flask приложения
start_flask_application() {
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    echo "Запуск Flask приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Flask приложение запущено."
}

# Основная последовательность выполнения
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database
push_to_repository
start_flask_application

echo "Выполнение скрипта успешно завершено: $(date)"
