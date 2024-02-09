#!/bin/bash

# Set strict execution mode and error handling
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2' ERR

# Define configuration variables
APP_DIR="/srv/talknet/backend/auth-service"  # Путь к каталогу приложения
VENV_DIR="$APP_DIR/venv"                    # Каталог виртуальной среды Python
LOG_DIR="/var/log/talknet"                   # Каталог журналов
BACKUP_DIR="/srv/talknet/backups"            # Каталог резервных копий базы данных
REQS_BACKUP_DIR="/tmp"                       # Временный каталог для резервной копии requirements.txt
PG_DB="prod_db"                              # Имя базы данных PostgreSQL
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"  # Файл журнала для текущего процесса обновления
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"  # URL репозитория
MAX_ATTEMPTS=3                               # Максимальное количество попыток для повторяемых операций
ATTEMPT=1                                    # Счетчик попыток

# Создание каталогов для журналов и резервных копий
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Перенаправление вывода скрипта в файл журнала
exec > >(tee -a "$LOG_FILE") 2>&1

# Создание резервной копии базы данных
create_database_backup() {
    echo "Создание резервной копии базы данных..."
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
        sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
    else
        echo "База данных $PG_DB не существует. Пропуск резервного копирования."
    fi
}

# Очистка текущей установки с сохранением важных файлов
cleanup() {
    echo "Очистка текущей установки..."
    # Сохранить существующий requirements.txt и app.py, если они существуют
    [ -f "$APP_DIR/requirements.txt" ] && cp "$APP_DIR/requirements.txt" "$REQS_BACKUP_DIR"
    [ -f "$APP_DIR/app.py" ] && cp "$APP_DIR/app.py" "$REQS_BACKUP_DIR"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

# Клонирование репозитория и установка зависимостей
setup() {
    echo "Клонирование репозитория и установка зависимостей..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
    # Восстановить сохраненный requirements.txt и app.py
    [ -f "$REQS_BACKUP_DIR/requirements.txt" ] && cp "$REQS_BACKUP_DIR/requirements.txt" "$APP_DIR"
    [ -f "$REQS_BACKUP_DIR/app.py" ] && cp "$REQS_BACKUP_DIR/app.py" "$APP_DIR"
    # Настройка виртуальной среды Python
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    # Проверить, существует ли requirements.txt, перед установкой
    if [ -f "requirements.txt" ]; then
        pip install -r "requirements.txt"
    else
        echo "Файл requirements.txt не найден. Невозможно установить зависимости Python."
        return 1
    fi
}

# Опционально восстановить базу данных из резервной копии
restore_database() {
    echo "Восстановление базы данных из резервной копии..."
    # Здесь должны содержаться команды для восстановления базы данных, если это необходимо
}

# Обновление репозитория
update_repository() {
    echo "Получение обновлений из репозитория..."
    cd "$APP_DIR"
    git pull || {
        echo "Попытка восстановления репозитория из-за ошибки..."
        git fetch --all
        git reset --hard origin/main
    }
}

# Активация виртуальной среды
activate_virtualenv() {
    echo "Активация виртуальной среды..."
    source "$VENV_DIR/bin/activate"
}

# Установка пакетов Python
install_python_packages() {
    echo "Установка пакетов Python..."
    pip install --upgrade pip
    pip install -r "requirements.txt"
}

# Запуск миграции базы данных
run_database_migration() {
    echo "Запуск миграции базы данных..."
    # Создать каталог миграций, если он не существует
    mkdir -p "$APP_DIR/migrations"
    flask db upgrade || {
        echo "Миграция не удалась. Попытка создания новой миграции..."
        flask db init
        flask db migrate
        flask db upgrade
    }
}

# ... предыдущий код ...

# Деактивация виртуальной среды
deactivate_virtualenv() {
    echo "Деактивация виртуальной среды..."
    deactivate || true  # Деактивация не должна вызывать ошибку, если не активирована
}

# Перезапуск приложения
restart_application() {
    echo "Перезапуск приложения..."
    # Здесь вы должны добавить команду для запуска вашего приложения, например, с помощью gunicorn
    # Замените 'app:app' на фактический объект приложения, если он отличается
    pkill gunicorn || true  # Игнорировать ошибки, если gunicorn не запущен
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Приложение перезапущено."
}

# Основная последовательность выполнения
echo "Запуск скрипта."
create_database_backup
cleanup
setup
# Опционально вызвать restore_database, если вы реализовали его
# restore_database
update_repository
activate_virtualenv
install_python_packages
run_database_migration
deactivate_virtualenv
restart_application
echo "Скрипт выполнен."

# Конец скрипта
