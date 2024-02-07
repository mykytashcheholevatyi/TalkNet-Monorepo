#!/bin/bash

# Определение основных переменных
LOG_DIR="/var/log/talknet"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало развертывания: $(date)"
sudo apt-get update

# Установка необходимых пакетов
DEPS="python3 python3-pip python3-venv git postgresql postgresql-contrib nginx"
for dep in $DEPS; do
    if ! dpkg -l | grep -qw $dep; then
        echo "Установка $dep..."
        sudo apt-get install -y $dep
    else
        echo "$dep уже установлен."
    fi
done

# Настройка PostgreSQL
PG_USER="your_username"
PG_DB="prod_db"
PG_PASSWORD="your_password"
echo "Настройка PostgreSQL..."
sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1 || sudo -u postgres createuser -P "$PG_USER"
sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || sudo -u postgres createdb -O "$PG_USER" "$PG_DB"

# Клонирование репозитория
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
APP_DIR="/srv/talknet"
if [ ! -d "$APP_DIR" ]; then
    echo "Клонирование репозитория..."
    git clone "$REPO_URL" "$APP_DIR"
else
    echo "Репозиторий уже существует. Выполняется pull..."
    cd "$APP_DIR" && git pull
fi

# Создание и активация виртуальной среды
VENV_DIR="$APP_DIR/backend/auth-service/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Создание виртуальной среды..."
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"

# Установка зависимостей Python
echo "Установка зависимостей Python..."
pip install --upgrade pip
pip install -r "$APP_DIR/backend/auth-service/requirements.txt"

# Настройка и запуск приложения
export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
export FLASK_ENV=production
export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"

# Создание бэкапа базы данных
BACKUP_DIR="/srv/talknet/backups"
mkdir -p "$BACKUP_DIR"
echo "Создание бэкапа базы данных..."
sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"

# Запуск приложения через Gunicorn
echo "Запуск приложения через Gunicorn..."
pkill gunicorn || true  # Остановка текущего процесса Gunicorn, если он запущен
gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"

echo "Приложение успешно развернуто и запущено: $(date)"
