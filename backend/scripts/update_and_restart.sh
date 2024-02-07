#!/bin/bash

set -e

echo "Начало обновления: $(date)"

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

# Проверка наличия виртуального окружения
if [ -d "$VENV_DIR" ]; then
    echo "Активация виртуального окружения..."
    source $VENV_DIR/bin/activate
else
    echo "Виртуальное окружение не найдено. Процесс остановлен."
    exit 1
fi

echo "Обновление зависимостей Python..."
if pip install --upgrade -r requirements.txt; then
    echo "Зависимости Python успешно обновлены."
else
    echo "Ошибка при обновлении зависимостей Python. Процесс остановлен."
    deactivate
    exit 1
fi

# Деактивация виртуального окружения
echo "Деактивация виртуального окружения..."
deactivate

# Перезапуск приложения через Gunicorn
echo "Перезапуск приложения через Gunicorn..."
pkill gunicorn || true
gunicorn --bind 0.0.0.0:8000 app:app --chdir $APP_DIR --daemon --log-file=$LOG_DIR/gunicorn.log --access-logfile=$LOG_DIR/access.log

echo "Приложение успешно обновлено и перезапущено."
