#!/bin/bash

# Initialization and strict mode
set -euo pipefail
trap 'echo "Error on line $LINENO. Exiting with code $?" >&2; exit 1' ERR

# Load environment variables
if [ -f /srv/talknet/.env ]; then
    source /srv/talknet/.env
else
    echo "Environment file not found, exiting..."
    exit 1
fi

# Directory paths
LOG_DIR="/srv/talknet/var/log"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
FLASK_APP_DIR="$APP_DIR/backend/auth-service"  # Adjusted to the Flask app directory
VENV_DIR="$FLASK_APP_DIR/venv"
SCHEMA_PATH="$FLASK_APP_DIR/database/schema.sql"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"

# Log file setup
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Deployment started: $(date)"

# Function definitions

rotate_logs() {
    find "$LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
    echo "Logs rotated."
}

install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git postgresql postgresql-contrib nginx
    echo "Dependencies installed."
}

test_db_connection() {
    if ! PGPASSWORD=$PG_PASSWORD psql -h localhost -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Database connection failed."
        return 1
    else
        echo "Database connection succeeded."
        return 0
    fi
}

apply_soft_updates() {
    echo "Applying soft updates..."
    # Iterate through soft update levels
    for level in {1..10}; do
        if ! soft_update_level_$level; then
            echo "Soft update level $level failed, trying next level..."
        else
            echo "Soft update level $level succeeded."
            return 0
        fi
    done
    echo "All soft updates failed."
    return 1
}

soft_update_level_1() { echo "Performing soft update level 1..."; return 1; }  # Placeholder for real function
# Define additional soft update functions as needed...

recreate_db() {
    echo "Recreating database and user..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $PG_DB;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $PG_USER;"
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"
    echo "Database and user recreated."
}

apply_schema() {
    echo "Applying database schema..."
    if [ -f "$SCHEMA_PATH" ]; then
        sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH" || { echo "Problem applying database schema."; exit 1; }
    else
        echo "Schema file not found at $SCHEMA_PATH. Exiting..."
        exit 1
    fi
}

backup_db() {
    echo "Backing up the database..."
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE" || { echo "Failed to backup database."; exit 1; }
    echo "Database backed up to $BACKUP_FILE."
}

clone_update_repo() {
    echo "Updating repository..."
    if [ ! -d "$FLASK_APP_DIR/.git" ]; then
        git clone "$REPO_URL" "$FLASK_APP_DIR"
    else
        cd "$FLASK_APP_DIR" && git pull || { echo "Failed to update repository."; exit 1; }
    fi
    echo "Repository updated."
}

setup_venv() {
    echo "Setting up the Python virtual environment..."
    python3 -m venv "$VENV_DIR" || { echo "Failed to create virtual environment."; exit 1; }
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip || { echo "Failed to upgrade pip."; exit 1; }
    REQUIREMENTS_PATH="$FLASK_APP_DIR/requirements.txt"
    if [ -f "$REQUIREMENTS_PATH" ]; then
        pip install -r "$REQUIREMENTS_PATH" || { echo "Failed to install dependencies."; exit 1; }
        echo "Dependencies from $REQUIREMENTS_PATH installed."
    else
        echo "requirements.txt not found in $FLASK_APP_DIR, skipping pip install."
    fi
}

apply_migrations() {
    echo "Applying database migrations..."
    source "$VENV_DIR/bin/activate"
    flask db upgrade || { echo "Failed to apply migrations."; exit 1; }
}

restart_services() {
    echo "Restarting application services..."
    pkill gunicorn || true
    gunicorn --chdir "$FLASK_APP_DIR" app:app --daemon || { echo "Failed to start gunicorn."; exit 1; }
    sudo systemctl restart nginx || { echo "Failed to restart nginx."; exit 1; }
    echo "Services restarted."
}

# Main logic

rotate_logs
install_dependencies

if ! test_db_connection; then
    echo "Attempting soft updates due to database connection failure."
    if ! apply_soft_updates; then
        echo "Soft updates failed, recreating database and user."
        recreate_db
    fi
fi

apply_schema
backup_db
clone_update_repo
setup_venv
apply_migrations
restart_services

echo "Deployment completed: $(date)"
