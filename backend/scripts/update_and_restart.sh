#!/bin/bash

set -euo pipefail
trap "echo 'Error: Script failed.'" ERR

echo "Начало полной очистки, обновления и восстановления проекта: $(date)"

# Конфигурация
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
MAX_ATTEMPTS=3
ATTEMPT=1

# Обработчик ошибок
error_exit() {
    echo "Произошла критическая ошибка."
    echo "Попытка откатить миграцию и перезапустить приложение..."
    flask db downgrade || true
    restart_application
    exit 1
}

# Создание бэкапа базы данных
create_database_backup() {
    echo "Создание бэкапа базы данных..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
}

# Очистка текущей установки
cleanup() {
    echo "Очистка текущей установки..."
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

# Клонирование репозитория и установка зависимостей
setup() {
    echo "Клонирование репозитория и установка зависимостей..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
}

# Восстановление базы данных (опционально)
restore_database() {
    echo "Восстановление базы данных..."
    # Здесь должен быть код для восстановления базы данных из бэкапа
}

# Обновление репозитория
update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR"
    if git pull; then
        echo "Репозиторий успешно обновлен."
    else
        echo "Ошибка при обновлении репозитория. Попытка восстановления..."
        git fetch --all
        git reset --hard origin/main
        echo "Репозиторий восстановлен."
    fi
}

# Активация виртуального окружения
activate_virtualenv() {
    echo "Активация виртуального окружения..."
    if [ -d "$VENV_DIR" ]; then
        source "$VENV_DIR/bin/activate"
    else
        echo "Виртуальное окружение не найдено. Создание..."
        python3 -m venv "$VENV_DIR"
        source "$VENV_DIR/bin/activate"
        python -m ensurepip --upgrade
    fi
}

# Установка пакетов Python
install_python_packages() {
    echo "Установка пакетов Python..."
    if pip install --upgrade pip && pip install --upgrade -r "$APP_DIR/requirements.txt"; then
        echo "Зависимости Python успешно обновлены."
    else
        echo "Ошибка при обновлении зависимостей Python. Попытка установки снова..."
        pip install --upgrade pip
        pip install --upgrade -r "$APP_DIR/requirements.txt"
    fi
}

# Выполнение миграции базы данных
run_database_migration() {
    while [ "$ATTEMPT" -le "$MAX_ATTEMPTS" ]; do
        echo "Попытка $ATTEMPT миграции базы данных..."
        echo "Выполнение миграции базы данных..."
        export FLASK_APP=app.py
        export FLASK_ENV=production

        if [ ! -d "$APP_DIR/migrations" ]; then
            flask db init
            echo "Миграционный репозиторий создан."
        fi

        if ! flask db migrate -m "Auto migration"; then
            echo "Ошибка при создании новых миграций. Удаление старых миграций и создание заново..."
            flask db stamp head
            flask db migrate
            flask db upgrade
        else
            echo "Миграция базы данных выполнена успешно."
            break
        fi

        ((ATTEMPT++))
    done
}

# Деактивация виртуального окружения
deactivate_virtualenv() {
    echo "Деактивация виртуального окружения..."
    deactivate
}

# Перезапуск приложения
restart_application() {
    echo "Перезапуск приложения..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

# Последовательное выполнение функций с логированием
create_database_backup || error_exit
cleanup || error_exit
setup || error_exit
restore_database || true # Продолжить выполнение даже если восстановление не удалось
update_repository || error_exit
activate_virtualenv || error_exit
install_python_packages || error_exit
run_database_migration || error_exit
deactivate_virtualenv || error_exit
restart_application || error_exit

# Завершение обновления
echo "Обновление успешно завершено: $(date)"
