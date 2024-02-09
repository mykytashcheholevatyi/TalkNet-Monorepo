#!/bin/bash

# Установка строгого режима выполнения и обработки ошибок
set -euo pipefail
trap 'echo "Произошла ошибка на строке $LINENO. Завершение с кодом ошибки $?" >&2; exit 1' ERR

# Определение переменных конфигурации
LOG_DIR="/srv/talknet/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Начало выполнения скрипта: $(date)"

# Функция для установки необходимых пакетов
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

# Функция настройки PostgreSQL
setup_postgresql() {
    echo "Настройка PostgreSQL..."
    # Укажите свои значения для переменных
    PG_USER="your_username"
    PG_DB="prod_db"
    PG_PASSWORD="your_password"
    if ! sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1; then
        echo "Создание пользователя PostgreSQL $PG_USER..."
        sudo -u postgres createuser -P "$PG_USER"
    else
        echo "Пользователь PostgreSQL $PG_USER уже существует."
    fi
    if ! sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1; then
        echo "Создание базы данных PostgreSQL $PG_DB..."
        sudo -u postgres createdb -O "$PG_USER" "$PG_DB"
    else
        echo "База данных PostgreSQL $PG_DB уже существует."
    fi
}

# Функция клонирования или обновления репозитория
clone_or_update_repository() {
    echo "Клонирование или обновление репозитория..."
    REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
    APP_DIR="/srv/talknet"
    if [ ! -d "$APP_DIR" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR"
        git pull -f
    fi
}

# Функция настройки Python виртуального окружения и установки зависимостей
setup_python_environment() {
    echo "Настройка Python виртуального окружения..."
    VENV_DIR="$APP_DIR/backend/auth-service/venv"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Установка зависимостей Python..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Функция резервного копирования базы данных
backup_database() {
    echo "Создание резервной копии базы данных..."
    BACKUP_DIR="/srv/talknet/backups"
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
}

# Функция отправки изменений в Git репозиторий
push_to_repository() {
    echo "Проверка изменений..."
    cd "$APP_DIR"
    # Проверяем, есть ли изменения в файлах, кроме директории backups
    if git status --porcelain | grep -v "^?? backups/" ; then
        echo "Отправка изменений в Git репозиторий..."
        git add .
        git commit -m "Автоматическое резервное копирование базы данных: $(date)"
        git push origin main
        echo "Изменения отправлены в Git репозиторий."
    else
        echo "Изменения касаются только бекапов. Отправка в Git репозиторий пропущена."
    fi
}

# Функция запуска Flask приложения
start_flask_application() {
    echo "Запуск Flask приложения..."
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
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
