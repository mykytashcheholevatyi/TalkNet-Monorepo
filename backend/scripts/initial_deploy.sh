#!/bin/bash

# Обновление списка пакетов и установка необходимых компонентов
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv git postgresql postgresql-contrib nginx

# Проверка и установка PostgreSQL
if ! command -v psql > /dev/null; then
    echo "Установка PostgreSQL..."
    sudo apt-get install -y postgresql postgresql-contrib
fi

# Настройка PostgreSQL: создание пользователя и базы данных
PG_USER="your_username"  # Измените на ваше имя пользователя
PG_DB="your_database_name"  # Измените на название вашей базы данных
echo "Настройка PostgreSQL..."
sudo -u postgres createuser --no-createdb --no-superuser --no-createrole --login $PG_USER
sudo -u postgres createdb --owner=$PG_USER $PG_DB

# Клонирование репозитория, если он ещё не склонирован
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
APP_DIR="/srv/talknet"
if [ ! -d "$APP_DIR" ]; then
    echo "Клонирование репозитория..."
    git clone $REPO_URL $APP_DIR
else
    echo "Репозиторий уже склонирован. Обновление..."
    cd $APP_DIR
    git pull
fi

# Установка и настройка Python виртуального окружения
echo "Настройка Python виртуального окружения..."
VENV_DIR="$APP_DIR/backend/auth-service/venv"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv $VENV_DIR
fi
source $VENV_DIR/bin/activate

# Установка зависимостей Python
echo "Установка зависимостей Python..."
pip install -r $APP_DIR/backend/auth-service/requirements.txt

# Настройка и запуск приложения
echo "Настройка и запуск приложения..."
export FLASK_APP=$APP_DIR/backend/auth-service/app.py
export FLASK_ENV=production
export DATABASE_URL="postgresql://$PG_USER:@localhost/$PG_DB"

# Инициализация и миграция базы данных, если требуется
# flask db upgrade  # Раскомментируйте, если используете Flask-Migrate

# Запуск приложения через Gunicorn
echo "Запуск приложения через Gunicorn..."
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR/backend/auth-service --daemon

echo "Приложение успешно развернуто и запущено."
