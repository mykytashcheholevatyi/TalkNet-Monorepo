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
FLASK_APP_DIR="$APP_DIR/backend/auth-service"
VENV_DIR="$FLASK_APP_DIR/venv"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$BACKUP_DIR" "$FLASK_APP_DIR"

# Log file setup
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Deployment started: $(date)"

# Rotate logs
rotate_logs() {
    find "$LOG_DIR" -name '*.log' -mtime +30 -exec rm {} \;
    echo "Logs rotated."
}

# Install required dependencies
install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git postgresql postgresql-contrib nginx
    echo "Dependencies installed."
}

# Test database connection
test_db_connection() {
    if ! PGPASSWORD=$PG_PASSWORD psql -h localhost -U $PG_USER -d $PG_DB -c '\q' 2>/dev/null; then
        echo "Database connection failed."
        return 1
    else
        echo "Database connection succeeded."
        return 0
    fi
}

# Apply schema if not already applied
apply_schema() {
    echo "Checking and applying database schema if necessary..."
    SCHEMA_PATH="$FLASK_APP_DIR/database/schema.sql"
    if [ -f "$SCHEMA_PATH" ]; then
        echo "Applying schema from $SCHEMA_PATH..."
        sudo -u postgres psql -d "$PG_DB" -f "$SCHEMA_PATH" || true  # Ignore errors in case tables already exist
    else
        echo "Schema file not found at $SCHEMA_PATH. Please check the path and try again."
    fi
}

# Backup the database
backup_db() {
    echo "Backing up the database..."
    BACKUP_FILE="$BACKUP_DIR/${PG_DB}_$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "Database backed up to $BACKUP_FILE."
}

# Update or clone the repository
clone_update_repo() {
    echo "Updating repository..."
    if [ -d "$FLASK_APP_DIR/.git" ]; then
        cd "$FLASK_APP_DIR" && git fetch --all && git reset --hard origin/main
    else
        git clone "$REPO_URL" "$FLASK_APP_DIR" && cd "$FLASK_APP_DIR"
    fi
    echo "Repository updated."
}

# Set up the Python virtual environment and install dependencies
setup_venv() {
    echo "Setting up the Python virtual environment..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    REQUIREMENTS_PATH="$FLASK_APP_DIR/requirements.txt"
    if [ -f "$REQUIREMENTS_PATH" ]; then
        pip install -r "$REQUIREMENTS_PATH"
        echo "Dependencies installed."
    else
        echo "Requirements file not found. Skipping dependency installation."
    fi
}

# Apply Flask database migrations
apply_migrations() {
    echo "Applying Flask database migrations..."
    source "$VENV_DIR/bin/activate"
    flask db upgrade || echo "Flask migrations applied or no migrations found."
}

# Restart the Flask application and Nginx
restart_services() {
    echo "Restarting Flask application and Nginx..."
    pkill gunicorn || true  # Stop any existing gunicorn processes
    gunicorn --bind 0.0.0.0:8000 --chdir "$FLASK_APP_DIR" "app:create_app()" --daemon  # Adjust the gunicorn command as needed
    sudo systemctl restart nginx
    echo "Services restarted."
}

# Main logic
rotate_logs
install_dependencies

if ! test_db_connection; then
    echo "Database connection test failed. Please check your database configuration."
    exit 1
fi

backup_db
apply_schema
clone_update_repo
setup_venv
apply_migrations
restart_services

echo "Deployment completed: $(date)"
