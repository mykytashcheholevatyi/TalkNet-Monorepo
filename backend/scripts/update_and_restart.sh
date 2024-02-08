#!/bin/bash

# Configuration
APP_DIR="/srv/talknet/backend/auth-service"
VENV_DIR="$APP_DIR/venv"
LOG_DIR="/var/log/talknet"
BACKUP_DIR="/srv/talknet/backups"
PG_DB="talknet_user_service"
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"

# Set strict mode for script execution
set -euo pipefail
trap 'echo "Error: Script failed." ; exit 1' ERR

# Backup the database
echo "Creating database backup..."
sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"

# Clean the current installation
echo "Cleaning current installation..."
rm -rf "$APP_DIR"/*
mkdir -p "$APP_DIR"

# Clone the repository
echo "Cloning the repository..."
git clone "$REPO_URL" "$APP_DIR" --single-branch

# Set up Python virtual environment
echo "Setting up virtual environment..."
python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

# Upgrade pip and install Python packages
echo "Installing dependencies..."
pip install --upgrade pip
pip install -r "$APP_DIR/requirements.txt"

# Check if the database exists, and create it if it does not
echo "Setting up the database..."
if ! sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
    sudo -u postgres createdb "$PG_DB"
fi

# Apply database migrations
echo "Applying database migrations..."
export FLASK_APP="$APP_DIR/app.py"
flask db upgrade

# Restart the application
echo "Restarting the application..."
pkill gunicorn || true
gunicorn --bind 0.0.0.0:8000 "app:app" --chdir "$APP_DIR" --daemon \
         --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"

echo "Deployment and database setup completed successfully: $(date)"
