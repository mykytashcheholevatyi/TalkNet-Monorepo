#!/bin/bash

# Configuration variables
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="talknet_user_service"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"

# Create necessary directories
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$APP_DIR"

# Redirect all output to a log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to check and backup the database
backup_database() {
  echo "Checking for existing database..."
  if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
    echo "Database found. Creating backup..."
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
  else
    echo "Database $PG_DB does not exist. Skipping backup."
  fi
}

# Function to clean the current installation
clean_installation() {
  echo "Cleaning current installation..."
  rm -rf "$APP_DIR"/*
}

# Function to clone repository
clone_repository() {
  echo "Cloning repository..."
  if git clone "$REPO_URL" "$APP_DIR"; then
    echo "Repository cloned."
  else
    echo "Failed to clone repository. Exiting."
    exit 1
  fi
}

# Function to set up Python virtual environment and install dependencies
setup_python_env() {
  echo "Setting up Python virtual environment..."
  python3 -m venv "$VENV_DIR"
  source "$VENV_DIR/bin/activate"
  pip install --upgrade pip
  if [ -f "$APP_DIR/requirements.txt" ]; then
    pip install -r "$APP_DIR/requirements.txt"
  else
    echo "requirements.txt not found. Exiting."
    exit 1
  fi
}

# Function to apply database migrations
apply_migrations() {
  echo "Applying database migrations..."
  export FLASK_APP="$APP_DIR/app.py"
  flask db upgrade || true
}

# Function to restart the application
restart_application() {
  echo "Restarting application..."
  pkill gunicorn || true
  gunicorn --bind 0.0.0.0:8000 "app:app" --chdir "$APP_DIR" --daemon \
           --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
}

# Main execution flow
backup_database
clean_installation
clone_repository
setup_python_env
apply_migrations
restart_application

echo "Deployment completed successfully: $(date)"
