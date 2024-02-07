#!/bin/bash

LOG_DIR="/var/log/talknet"
mkdir -p $LOG_DIR
LOG_FILE="$LOG_DIR/deploy.log"

exec > >(tee -a $LOG_FILE) 2>&1

echo "Начало развертывания: $(date)"

# Функция для проверки и установки необходимых пакетов
ensure_package_installed() {
    PACKAGE_NAME=$1
    if dpkg -l | grep -qw $PACKAGE_NAME; then
        echo "$PACKAGE_NAME уже установлен."
    else
        echo "Установка $PACKAGE_NAME..."
        sudo apt-get install -y $PACKAGE_NAME
    fi
}

# Обновление списка пакетов
sudo apt-get update

# Проверка и установка необходимых компонентов
ensure_package_installed python3
ensure_package_installed python3-pip
ensure_package_installed python3-venv
ensure_package_installed git
ensure_package_installed postgresql
ensure_package_installed postgresql-contrib
ensure_package_installed nginx

# Настройка PostgreSQL
PG_USER="your_username"
PG_DB="your_database_name"
PG_PASSWORD="your_password"

echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1 || sudo -u postgres createuser -P $PG_USER
sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || sudo -u postgres createdb -O $PG_USER $PG_DB

# Клонирование или обновление репозитория
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
APP_DIR="/srv/talknet"

if [ ! -d "$APP_DIR" ]; then
    echo "Клонирование репозитория..."
    git clone $REPO_URL $APP_DIR
else
    echo "Репозиторий уже существует. Выполняется pull..."
    cd $APP_DIR && git pull
fi

# Установка и настройка Python виртуального окружения
VENV_DIR="$APP_DIR/backend/auth-service/venv"

if [ ! -d "$VENV_DIR" ]; then
    echo "Создание виртуального окружения..."
    python3 -m venv $VENV_DIR
fi

source $VENV_DIR/bin/activate

# Установка зависимостей Python
echo "Установка зависимостей Python..."
pip install -r $APP_DIR/backend/auth-service/requirements.txt

# Настройка и запуск приложения
export FLASK_APP=$APP_DIR/backend/auth-service/app.py
export FLASK_ENV=production
export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"

# Создание бэкапа базы данных перед обновлением
BACKUP_DIR="/srv/talknet/backups"
mkdir -p $BACKUP_DIR
echo "Создание бэкапа базы данных..."
sudo -u postgres pg_dump $PG_DB > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"

# Запуск миграций базы данных, если требуется
# flask db upgrade  # Раскомментируйте, если используете Flask-Migrate

# Запуск приложения через Gunicorn
echo "Запуск приложения через Gunicorn..."
pkill gunicorn || true  # Остановка текущего процесса Gunicorn, если он запущен
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR/backend/auth-service --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно развернуто и запущено: $(date)"
