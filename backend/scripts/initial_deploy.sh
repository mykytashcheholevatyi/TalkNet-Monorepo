#!/bin/bash

# Обновление списка пакетов
sudo apt-get update

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

# Проверка и установка необходимых компонентов
ensure_package_installed python3
ensure_package_installed python3-pip
ensure_package_installed python3-venv
ensure_package_installed git
ensure_package_installed postgresql
ensure_package_installed postgresql-contrib
ensure_package_installed nginx

# Настройка PostgreSQL
PG_USER="your_username"  # Замените на ваше имя пользователя
PG_DB="your_database_name"  # Замените на название вашей базы данных

echo "Настройка PostgreSQL..."
if ! sudo -u postgres psql -c "\du" | cut -d \| -f 1 | grep -qw $PG_USER; then
    sudo -u postgres createuser --no-createdb --no-superuser --no-createrole --login $PG_USER
    echo "Пользователь $PG_USER создан."
fi

if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $PG_DB; then
    sudo -u postgres createdb --owner=$PG_USER $PG_DB
    echo "База данных $PG_DB создана."
fi

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
export DATABASE_URL="postgresql://$PG_USER:@localhost/$PG_DB"

# Запуск приложения через Gunicorn
if ! command -v gunicorn > /dev/null; then
    pip install gunicorn
fi

echo "Запуск приложения через Gunicorn..."
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR/backend/auth-service --daemon --log-file=$APP_DIR/backend/auth-service/gunicorn.log --access-logfile=$APP_DIR/backend/auth-service/access.log

echo "Приложение успешно развернуто и запущено."
