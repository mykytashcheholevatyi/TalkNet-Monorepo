#!/bin/bash

set -e

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

# Перезапуск приложения
pkill gunicorn || true  # Игнорировать ошибку, если процесс не найден
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно обновлено и перезапущено."
