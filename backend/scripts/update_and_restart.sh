```bash
#!/bin/bash

set -e

echo "Начало обновления: $(date)"

APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"

create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    if sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"; then
        echo "Бэкап базы данных создан успешно."
    else
        echo "Ошибка при создании бэкапа базы данных. Процесс остановлен."
        exit 1
    fi
}

update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR"
    if git pull; then
        echo "Репозиторий успешно обновлен."
    else
        echo "Ошибка при обновлении репозитория. Процесс остановлен."
        exit 1
    fi
}

activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if [ -d "$VENV_DIR" ]; then
        . "$VENV_DIR/bin/activate"
    else
        echo "Виртуальное окружение не найдено. Создание..."
        python3 -m venv "$VENV_DIR"
        . "$VENV_DIR/bin/activate"
        python -m ensurepip --upgrade
    fi
}

install_python_packages() {
    echo "Установка пакетов Python..."
    if pip install --upgrade pip && pip install --upgrade -r "$APP_DIR/requirements.txt"; then
        echo "Зависимости Python успешно обновлены."
    else
        echo "Ошибка при обновлении зависимостей Python."
        deactivate
        exit 1
    fi
}

run_database_migration() {
    echo "Миграция базы данных..."
    export FLASK_APP=app.py
    export FLASK_ENV=production

    if [ ! -d "$APP_DIR/migrations" ]; then
        flask db init
        echo "Миграционный репозиторий создан."
    fi

    if ! flask db migrate -m "Auto migration"; then
        echo "Ошибка при создании новых миграций."
        rollback_database_migration
        return
    fi

    if ! flask db upgrade; then
        echo "Ошибка при применении миграций."
        rollback_database_migration
    else
        echo "Миграция базы данных выполнена успешно."
    fi
}

rollback_database_migration() {
    echo "Сброс миграции базы данных..."
    if flask db downgrade base; then
        echo "Миграция отменена. Проверьте миграционные скрипты."
    else
        echo "Ошибка при отмене миграций."
    fi
    deactivate
    exit 1
}

deactivate_virtualenv() {
    echo "Деактивация виртуального окружения..."
    deactivate
}

restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
deactivate_virtualenv
restart_application
```