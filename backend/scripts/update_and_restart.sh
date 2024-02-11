 #!/bin/bash

# Строгий режим
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Инициализация
ENV_FILE="/srv/talknet/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Файл с переменными среды $ENV_FILE не найден, завершение..."
  exit 1
fi
source "$ENV_FILE"

# Пути
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"

# Логирование
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Начало развёртывания: $(date)"

# Ротация журналов
rotate_logs() {
  find "$LOG_DIR" -type f -name '*.log' -mtime +30 -exec rm {} \;
  echo "Старые журналы очищены."
}

# Функция для работы с PostgreSQL
postgres() {
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
      sudo sed -i "s|#listen_addresses = 'localhost'|listen_addresses = '85.215.65.78'|" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
      sudo sed -i "s|#port = 5432|port = 5432|" "/etc/postgresql/$PG_VERSION/main/postgresql.conf"
      echo "host all all 85.215.65.78/32 md5" | sudo tee -a "/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
      echo "PostgreSQL настроен для приема подключений."
      ;;
    "restart")
      echo "Перезапуск PostgreSQL..."
      sudo systemctl restart postgresql
      echo "PostgreSQL перезапущен."
      ;;
  esac
}

# Функция для работы с базой данных
db() {
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
      BACKUP_FILE="<span class="math-inline">BACKUP\_DIR/</span>{PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
      PGPASSWORD=$PG_PASSWORD pg_dump -h $PG_HOST -U $PG_USER $PG_DB > "$BACKUP_FILE"
      echo "База данных скопирована в $BACKUP_FILE."
      ;;
  esac
}

# Зависимости
install_dependencies() {
  sudo apt-get install -y python3 python3-pip python3-venv git nginx
  echo "Зависимости установлены."
}

# Подключение к базе данных
test_db_connection() {
  if ! PGPASSWORD=$PG_PASSWORD psql -h 85.215.65.78 -U $PG_USER -d $PG_DB -c '\q'; then
    echo "Ошибка подключения к базе данных. Перезапуск PostgreSQL и повторная проверка..."
    postgres restart
    if ! PGPASSWORD=$PG_PASSWORD psql -h 85.215.65.78 -U $PG_USER -d $PG_DB -c '\q'; then
      echo "Ошибка подключения к базе данных после перезапуска PostgreSQL."
      exit 1
    fi
  fi
  echo "Подключение к базе данных успешно."
}

# Применение схемы
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

# Обновление или клонирование репозитория
clone_update_repo() {
  if [ -d "$FLASK_APP_DIR/.git" ]; then
    cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard $REPO_BRANCH
  else
    git clone $REPO_URL "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    git checkout $REPO_BRANCH
  fi
  echo "Репозиторий обновлен."
}

# Настройка виртуального окружения Python и установка зависимостей
setup_venv() {
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
  export FLASK_APP="$FLASK_APP_DIR/app.py" # Адаптировать под точку входа вашего приложения Flask

  if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
    flask db init
  fi

  flask db migrate -m "Автоматически сгенерированная миграция."
  flask db upgrade || echo "Нет миграций для применения или миграция не удалась."
}

# Перезапуск приложения Flask и Nginx
restart_services() {
  pkill gunicorn || true
  cd "$FLASK_APP_DIR"
  gunicorn --workers $GUNICORN_WORKERS --bind $GUNICORN_BIND "app:create_app()" --daemon
  sudo systemctl restart nginx
  echo "Приложение Flask и Nginx перезапущены."
}

# Основная логика
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