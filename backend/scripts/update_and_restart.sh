#!/bin/bash

# **Строгий режим:**
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# **Определение констант:**

# Версия PostgreSQL
readonly PG_VERSION="14"

# Настройки PostgreSQL
readonly PG_HOST="85.215.65.78"
readonly PG_PORT="5432"
readonly PG_DB="talknet_db"
readonly PG_USER="talknet_user"
readonly PG_PASSWORD="your_secure_password"

# Настройки репозитория
readonly REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo.git"
readonly REPO_BRANCH="main"

# Настройки приложения Flask
readonly FLASK_APP_DIR="/srv/talknet/backend/auth-service"
readonly FLASK_RUN_HOST="0.0.0.0"
readonly FLASK_RUN_PORT="8000"

# Настройки виртуального окружения Python
readonly VENV_DIR="$FLASK_APP_DIR/venv"

# Директории для логов и резервных копий
readonly LOG_DIR="/srv/talknet/var/log"
readonly BACKUP_DIR="/srv/talknet/backups"

# Настройки Gunicorn (если используется)
readonly GUNICORN_WORKERS="3"
readonly GUNICORN_BIND="0.0.0.0:8000"

# **Функции:**

# Ротация журналов
function rotate_logs() {
  find "$LOG_DIR" -type f -name "*.log" -mtime +30 -exec rm {} \;
  echo "Старые журналы очищены."
}

# Работа с PostgreSQL
function postgres() {
  local action="$1"
  case "$action" in
    "install")
      echo "Установка PostgreSQL..."
      sudo apt-get update
      sudo apt-get install -y "postgresql-$PG_VERSION" "postgresql-contrib-$PG_VERSION"
      echo "PostgreSQL успешно установлен."
      ;;
    "init")
      echo "Инициализация кластера базы данных PostgreSQL..."
      sudo pg_dropcluster --stop $PG_VERSION main || true
      sudo pg_createcluster $PG_VERSION main --start
      echo "Кластер PostgreSQL инициализирован."
      ;;
    "configure")
      echo "Настройка PostgreSQL для приема подключений..."
      sudo sed -i "s|#listen_addresses = 'localhost'|listen_addresses = '*'" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
      sudo sed -i "s|#port = 5432|port = 5432|" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
      echo "host all all 0.0.0.0/0 md5" | sudo tee -a "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
      echo "PostgreSQL настроен для приема подключений."
      ;;
    "restart")
      echo "Перезапуск PostgreSQL..."
      sudo systemctl restart postgresql
      echo "PostgreSQL перезапущен."
      ;;
  esac
}

# Работа с базой данных
function db() {
  local action="$1"
  case "$action" in
    "create-user")
      echo "Создание пользователя PostgreSQL..."
      sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
      echo "Пользователь PostgreSQL создан."
      ;;
    "create-database")
      echo "Создание базы данных PostgreSQL..."
      sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
      echo "База данных PostgreSQL создана."
      ;;
    "backup")
      local backup_file="$BACKUP_DIR/<span class="math-inline">PG\_DB\_</span>(date +%Y-%m-%d_%H-%M-%S).sql"
      PGPASSWORD="$PG_PASSWORD" pg_dump -h "$PG_HOST" -U "$PG_USER" "$PG_DB" > "$backup_file"
      echo "База данных скопирована в $backup_file."
      ;;
  esac
}

# **Зависимости:**

function install_dependencies() {
  sudo apt-get install -y python3 python3-pip python3-venv git nginx
  echo "Зависимости установлены."
}

# **Подключение к базе данных:**

function test_db_connection() {
  if ! PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c '\q'; then
    echo "Ошибка подключения к базе данных. Перезапуск PostgreSQL и повторная проверка..."
    postgres restart
    if ! PGPASSWORD="$PG_PASSWORD" psql -h "$PG_HOST" -U "$PG_USER" -d "$PG_DB" -c '\q'; then
      echo "Ошибка подключения к базе данных после перезапуска PostgreSQL."
      exit 1
    fi
  fi
  echo "Подключение к базе данных успешно."
}

# **Применение схемы:**

function apply_schema() {
  echo "Применение схемы базы данных..."
  local schema_path="$FLASK_APP_DIR/database/schema.sql"
  if [ -f "$schema_path" ]; then
    sudo -u postgres psql -d "$PG_DB" -a -f "$schema_path"
    echo "Схема применена из $schema_path."
  else
    echo "Файл схемы не найден по пути $schema_path. Пожалуйста, проверьте путь и повторите попытку."
  fi
}

# **Обновление или клонирование репозитория:**

function clone_update_repo() {
  if [ -d "$FLASK_APP_DIR/.git" ]; then
    cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard "$REPO_BRANCH"
  else
    git clone "$REPO_URL" "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    git checkout "$REPO_BRANCH"
  fi
  echo "Репозиторий обновлен."
}

# **Настройка виртуального окружения Python и установка зависимостей:**

function setup_venv() {
  python3 -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install -r "$FLASK_APP_DIR/requirements.txt"
  echo "Зависимости установлены."
}

# **Применение миграций базы данных Flask:**

function apply_migrations() {
  echo "Применение миграций базы данных Flask..."
  source "$VENV_DIR/bin/activate"
  export FLASK_APP="$FLASK_APP_DIR/app.py" # Адаптируйте под точку входа вашего приложения Flask

  if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
    flask db init
  fi

  flask db migrate -m "Автоматически сгенерированная миграция."
  flask db upgrade || echo "Нет миграций для применения или миграция не удалась."
}

# **Перезапуск приложения Flask и Nginx:**

function restart_services() {
  pkill gunicorn || true
  cd "$FLASK_APP_DIR"
  gunicorn --workers "$GUNICORN_WORKERS" --bind "$GUNICORN_BIND" "app:create_app()" --daemon
  sudo systemctl restart nginx
  echo "Приложение Flask и Nginx перезапущены."
}

# **Основная логика:**

rotate_logs
install_dependencies
postgres install
postgres init
postgres configure
db create-user
db create-database
db backup
test_db_connection
apply_schema
clone_update_repo
setup_venv
apply_migrations
restart_services

echo "Развёртывание завершено: $(date)"
