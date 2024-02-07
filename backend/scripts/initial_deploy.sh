#!/bin/bash

# Настройка переменных
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
APP_DIR="/srv/talknet/backend"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"

# Установка PostgreSQL
sudo apt-get update
sudo apt-get install -y postgresql postgresql-contrib

# Создание пользователя и базы данных для производственной среды
sudo -u postgres createuser --interactive --pwprompt
sudo -u postgres createdb -O username prod_db  # Замените 'username' и 'prod_db' на ваши значения

# Создание структуры каталогов
sudo mkdir -p $APP_DIR $LOG_DIR
sudo chown -R $USER:$USER $APP_DIR $LOG_DIR

# Клонирование репозитория
git clone $REPO_URL $APP_DIR

# Настройка виртуального окружения и установка зависимостей
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate
pip install -r $APP_DIR/requirements.txt

# Настройка переменных окружения
export FLASK_APP=$APP_DIR/app.py
export FLASK_ENV=production
export DATABASE_URL='postgresql://username:password@localhost/prod_db'

# Инициализация базы данных
python $APP_DIR/app.py

# Запуск приложения в фоне с логированием
gunicorn --bind 0.0.0.0:8000 app:app --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно развернуто и запущено."
