#!/bin/bash

set -e

echo "Начало обновления: $(date)"

# Настройка переменных
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"

# Создание бэкапа базы данных
echo "Создание бэкапа базы данных..."
mkdir -p $BACKUP_DIR
if sudo -u postgres pg_dump $PG_DB > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"; then
    echo "Бэкап базы данных создан успешно."
else
    echo "Ошибка при создании бэкапа базы данных. Процесс остановлен."
    exit 1
fi

# Получение обновлений из репозитория
echo "Получение обновлений из репозитория..."
cd $APP_DIR
if git pull; then
    echo "Репозиторий успешно обновлен."
else
    echo "Ошибка при обновлении репозитория. Процесс остановлен."
    exit 1
fi

# Активация виртуального окружения
source $VENV_DIR/bin/activate

# Обновление зависимостей Python
echo "Обновление зависимостей Python..."
if pip install -r requirements.txt; then
    echo "Зависимости Python успешно обновлены."
else
    echo "Ошибка при обновлении зависимостей Python. Процесс остановлен."
    exit 1
fi

# Миграция базы данных
echo "Миграция базы данных..."
export FLASK_APP=app.py
export FLASK_ENV=production
if flask db upgrade; then
    echo "Миграция базы данных выполнена успешно."
else
    echo "Ошибка при миграции базы данных. Процесс остановлен."
    exit 1
fi

# Перезапуск приложения через Gunicorn
echo "Перезапуск приложения через Gunicorn..."
pkill gunicorn || true  # Игнорировать ошибку, если процесс не найден
if gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log; then
    echo "Приложение успешно обновлено и перезапущено."
else
    echo "Ошибка при запуске приложения через Gunicorn. Процесс остановлен."
    exit 1
fi
