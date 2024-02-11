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
VENV_DIR="$APP_DIR/venv"
SCHEMA_PATH="$APP_DIR/database/schema.sql"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

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
        return 1
    fi
    return 0
}

apply_soft_updates() {
    for level in {1..10}; do
        if ! soft_update_level_$level; then
            echo "Soft update level $level failed."
            continue
        else
            echo "Soft update level $level applied successfully."
            return 0
        fi
    done
    return 1
}

soft_update_level_1() { echo "Dummy soft update level 1"; return 1; } # Placeholder for real function
# Define additional soft update functions as needed...

recreate_db() {
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $PG_DB;"
    sudo -u postgres psql -c "DROP USER IF EXISTS $PG_USER;"
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"
    echo "Database and user recreated."
}

apply_schema() {
    sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH" || true
    echo "Database schema applied."
}

backup_db() {
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "Database backed up."
}

clone_update_repo() {
    if [ ! -d "$APP_DIR/.git" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR" && git pull
    fi
    echo "Repository updated."
}

setup_venv() {
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$APP_DIR/requirements.txt"
    echo "Virtual environment set up."
}

apply_migrations() {
    source "$VENV_DIR/bin/activate"
    flask db upgrade
    echo "Database migrations applied."
}

restart_services() {
    pkill gunicorn || true
    gunicorn --chdir "$APP_DIR" app:app --daemon
    sudo systemctl restart nginx
    echo "Services restarted."
}

# Main logic

rotate_logs
install_dependencies

if ! test_db_connection; then
    echo "Database connection failed. Attempting soft updates."
    if ! apply_soft_updates; then
        echo "Soft updates failed. Recreating database and user."
        recreate_db
        apply_schema
    fi
else
    echo "Database connection successful."
fi

backup_db
clone_update_repo
setup_venv
apply_migrations
restart_services

echo "Deployment completed: $(date)"
