#!/bin/bash

# Инициализация и строгий режим
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Исправление прерванных установок пакетов
fix_interrupted_package_installation() {
    echo "Проверка и исправление прерванных установок пакетов..."
    sudo dpkg --configure -a
    echo "Прерванные установки пакетов исправлены."
}

# Вызов функции исправления прерванных установок в самом начале
fix_interrupted_package_installation

# Загрузка переменных среды
ENV_FILE="/srv/talknet/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Файл с переменными среды $ENV_FILE не найден, завершение..."
    exit 1
fi

# Пути к каталогам
LOG_DIR="/srv/talknet/var/log"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
FLASK_APP_DIR="$APP_DIR/backend/auth-service"
VENV_DIR="$FLASK_APP_DIR/venv"

# Остальная часть скрипта...

# Проверка существования каталогов
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"

# Настройка файла журнала
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало развёртывания: $(date)"



# Поворот журналов
rotate_logs() {
    find "$LOG_DIR" -type f -name '*.log' -mtime +30 -exec rm {} \;
    echo "Старые журналы очищены."
}

# Жесткая установка PostgreSQL
install_postgresql() {
    echo "Установка PostgreSQL..."

    local installed_version="14" # Желаемая версия PostgreSQL

    # Автоматическое подтверждение удаления директорий PostgreSQL
    echo "postgresql-$installed_version postgresql/$installed_version/postrm_purge_databases boolean true" | sudo debconf-set-selections

    # Удаление существующей версии, если она установлена
    sudo apt-get remove --purge -qq -y "postgresql-$installed_version" "postgresql-contrib-$installed_version"
    
    # Удаление оставшихся файлов конфигурации и данных
    sudo rm -rf /var/lib/postgresql/
    sudo rm -rf /etc/postgresql/

    # Установка желаемой версии PostgreSQL
    sudo apt-get install -qq -y "postgresql-$installed_version" "postgresql-contrib-$installed_version"
    echo "PostgreSQL успешно установлен."
}



# Инициализация кластера базы данных PostgreSQL
init_db_cluster() {
    local version="14" # Версия PostgreSQL

    sudo pg_dropcluster --stop "$version" main || true  # Удалить существующий кластер, если существует
    sudo pg_createcluster "$version" main --start  # Создать новый кластер
    echo "Кластер PostgreSQL инициализирован."
}

# Настройка PostgreSQL для приема подключений
configure_postgresql() {
    local version=$(pg_lsclusters | awk '/main/ {print $1}')
    sudo sed -i "/^#listen_addresses = 'localhost'/c\listen_addresses = '*'" "/etc/postgresql/$version/main/postgresql.conf"
    sudo sed -i "/^#port = 5432/c\port = 5432" "/etc/postgresql/$version/main/postgresql.conf"

    echo "host all all all md5" | sudo tee -a "/etc/postgresql/$version/main/pg_hba.conf"
    sudo systemctl restart postgresql
    echo "PostgreSQL настроен для приема подключений."
}

# Создание пользователя и базы данных PostgreSQL
create_db_user_and_database() {
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';" || true
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;" || true
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB TO $PG_USER;" || true
    echo "База данных и пользователь созданы."
}

# Установка необходимых зависимостей
install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git nginx
    echo "Зависимости установлены."
}

# Тестирование подключения к базе данных
test_db_connection() {
    if ! PGPASSWORD=$PG_PASSWORD psql -h localhost -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Ошибка подключения к базе данных."
        return 1
    else
        echo "Подключение к базе данных успешно."
        return 0
    fi
}

# Применение схемы базы данных
apply_schema() {
    echo "Применение схемы базы данных..."
    SCHEMA_PATH="$FLASK_APP_DIR/database/schema.sql"
    if [ -f "$SCHEMA_PATH" ]; then
        sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH"
        echo "Схема применена из $SCHEMA_PATH."
    else
        echo "Файл схемы не найден по пути $SCHEMA_PATH. Пожалуйста, проверьте путь и повторите попытку."
    fi
}

# Резервное копирование базы данных
backup_db() {
    echo "Резервное копирование базы данных..."
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "База данных скопирована в $BACKUP_FILE."
}

# Обновление или клонирование репозитория
clone_update_repo() {
    echo "Обновление репозитория..."
    if [ -d "$FLASK_APP_DIR/.git" ]; then
        cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard origin/main
    else
        git clone "$REPO_URL" "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    fi
    echo "Репозиторий обновлен."
}

# Настройка виртуального окружения Python и установка зависимостей
setup_venv() {
    echo "Настройка виртуального окружения Python..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$FLASK_APP_DIR/requirements.txt"
    echo "Зависимости установлены."
}

# Применение миграций базы данных Flask
apply_migrations() {
    echo "Применение миграций базы данных Flask..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$FLASK_APP_DIR/app.py"  # Адаптировать под точку входа вашего приложения Flask

    if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
        flask db init
    fi

    flask db migrate -m "Автоматически сгенерированная миграция."
    flask db upgrade || echo "Нет миграций для применения или миграция не удалась."
}

# Перезапуск приложения Flask и Nginx
restart_services() {
    echo "Перезапуск приложения Flask и Nginx..."
    # Замените на ваши фактические команды для перезапуска Flask и Nginx
    pkill gunicorn || true
    cd "$FLASK_APP_DIR"
    gunicorn --bind 0.0.0.0:8000 "app:create_app()" --daemon
    sudo systemctl restart nginx
    echo "Приложение Flask и Nginx перезапущены."
}

# Основная логика
rotate_logs
install_dependencies
sudo dpkg --configure -a
install_postgresql
init_db_cluster
configure_postgresql
create_db_user_and_database
test_db_connection || { echo "Ошибка конфигурации базы данных. Прерывание."; exit 1; }
backup_db
clone_update_repo
setup_venv
apply_schema
apply_migrations
restart_services
# Вызов функции исправления прерванных установок
fix_interrupted_package_installation


echo "Развёртывание завершено: $(date)"
