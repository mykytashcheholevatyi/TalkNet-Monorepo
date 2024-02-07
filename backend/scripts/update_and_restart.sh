#!/bin/bash

# Настройка переменных
APP_DIR="/srv/talknet/backend"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"

# Бэкап базы данных
mkdir -p $BACKUP_DIR
sudo -u postgres pg_dump prod_db > $BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql

# Получение обновлений из репозитория
cd $APP_DIR
git pull

# Активация виртуального окружения и обновление зависимостей
source $VENV_DIR/bin/activate
pip install -r requirements.txt

# Инициализация и миграция базы данных
export FLASK_APP=app.py
export FLASK_ENV=production
export DATABASE_URL='postgresql://username:password@localhost/prod_db'
flask db upgrade  # Если используется Flask-Migrate

# Перезапуск приложения
pkill gunicorn
gunicorn --bind 0.0.0.0:8000 app:app --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно обновлено и перезапущено."
