#!/bin/bash

set -e

echo "Начало обновления: $(date)"

# Настройка переменных
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"  # Убедитесь, что название базы данных соответствует названию в вашем приложении

# Бэкап базы данных
echo "Создание бэкапа базы данных..."
mkdir -p $BACKUP_DIR
sudo -u postgres pg_dump $PG_DB > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"

# Получение обновлений из репозитория
echo "Получение обновлений из репозитория..."
cd $APP_DIR
git pull

# Обновление зависимостей Python
echo "Обновление зависимостей Python..."
source $VENV_DIR/bin/activate
pip install -r requirements.txt

# Инициализация и миграция базы данных
export FLASK_APP=app.py
export FLASK_ENV=production
flask db upgrade  # Если используется Flask-Migrate для миграций

# Перезапуск приложения через Gunicorn
echo "Перезапуск приложения через Gunicorn..."
pkill gunicorn || true  # Игнорировать ошибку, если процесс не найден
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно обновлено и перезапущено: $(date)"
