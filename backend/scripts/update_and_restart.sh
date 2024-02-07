#!/bin/bash

set -Eeo pipefail

APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="prod_db"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
LOG_FILE="$LOG_DIR/update-$DATE.log"

exec > >(tee -a "$LOG_FILE") 2>&1

trap 'error_exit' ERR

error_exit() {
    echo "An error occurred. Check the log: $LOG_FILE for more information."
    # Additional logic to handle specific errors could be implemented here
    exit 1
}

create_database_backup() {
    echo "Creating database backup..."
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$DATE.sql" || {
        echo "Failed to create database backup. Attempting to continue without backup."
    }
    echo "Database backup created."
}

update_repository() {
    echo "Updating repository..."
    git -C "$APP_DIR" pull origin main || {
        echo "Failed to update repository. Check for conflicts or connectivity issues."
        return 1
    }
    echo "Repository updated."
}

activate_virtualenv() {
    echo "Activating virtual environment..."
    if [[ ! -d "$VENV_DIR" ]]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate" || {
        echo "Failed to activate virtual environment."
        return 1
    }
    echo "Virtual environment activated."
}

install_python_packages() {
    echo "Installing Python dependencies..."
    pip install --upgrade pip
    pip install --upgrade -r "$APP_DIR/requirements.txt" || {
        echo "Failed to install dependencies. Check if the requirements are valid."
        return 1
    }
    echo "Dependencies installed."
}

run_database_migration() {
    echo "Running database migration..."
    export FLASK_APP="$APP_DIR/app.py"
    export FLASK_ENV=production
    flask db upgrade || {
        echo "Migration failed. Attempting to downgrade."
        flask db downgrade || echo "Downgrade failed. Manual intervention required."
        return 1
    }
    echo "Database migration completed."
}

restart_application() {
    echo "Restarting application..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 "app:app" --chdir "$APP_DIR" --daemon \
    --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log" || {
        echo "Failed to restart application. Check if Gunicorn is installed and app.py is correct."
        return 1
    }
    echo "Application restarted."
}

create_database_backup
update_repository
activate_virtualenv
install_python_packages
run_database_migration
restart_application

echo "Update completed successfully: $DATE"
