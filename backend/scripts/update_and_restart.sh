#!/bin/bash

# Script configuration
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
REQS_FILE="$APP_DIR/requirements.txt"
APP_FILE="$APP_DIR/app.py"
PG_DB="talknet_user_service"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"

# Ensure running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit
fi

# Set strict mode for script execution
set -euo pipefail
trap 'echo "Error: Script failed." ; exit 1' ERR

# Function definitions

# Check if PostgreSQL is running
ensure_postgres_running() {
  if ! pg_isready; then
    echo "PostgreSQL is not running. Trying to start..."
    systemctl start postgresql
  fi
}

# Create a backup of the database
backup_database() {
  ensure_postgres_running
  if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
    echo "Creating database backup..."
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
  else
    echo "Database $PG_DB does not exist. Skipping backup."
  fi
}

# Clean current installation
clean_installation() {
  echo "Cleaning current installation..."
  rm -rf "$APP_DIR"
  mkdir -p "$APP_DIR"
}

# Clone repository
clone_repository() {
  echo "Cloning repository..."
  git clone "$REPO_URL" "$APP_DIR" || {
    echo "Failed to clone repository. Exiting."
    exit 1
  }
}

# Set up Python virtual environment and install dependencies
setup_python_env() {
  echo "Setting up Python virtual environment..."
  python3 -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  pip install -r "$REQS_FILE"
}

# Create or update the database
create_or_update_db() {
  ensure_postgres_running
  if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
    echo "Creating database $PG_DB..."
    sudo -u postgres createdb "$PG_DB"
  fi
}

# Apply database migrations
apply_migrations() {
  echo "Applying database migrations..."
  export FLASK_APP="$APP_FILE"
  flask db upgrade || {
    echo "Migrations failed. Attempting to initialize new migrations..."
    flask db init
    flask db migrate
    flask db upgrade
  }
}

# Restart the application
restart_application() {
  echo "Restarting application..."
  # Assuming gunicorn is used with Flask application
  pkill gunicorn || true
  gunicorn --bind 0.0.0.0:8000 "app:create_app()" --chdir "$APP_DIR" --daemon \
           --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
}

# Main execution flow
echo "Starting backend setup: $(date)"
backup_database
clean_installation
clone_repository
setup_python_env
create_or_update_db
apply_migrations
restart_application
echo "Backend setup completed: $(date)"
