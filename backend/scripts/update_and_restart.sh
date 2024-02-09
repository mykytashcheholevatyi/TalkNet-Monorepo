#!/bin/bash

# Set strict execution mode and error handling
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2' ERR

# Define configuration variables
APP_DIR="/srv/talknet/backend/auth-service"  # Path to the application directory
VENV_DIR="$APP_DIR/venv"                    # Python virtual environment directory
LOG_DIR="/var/log/talknet"                  # Log directory
BACKUP_DIR="/srv/talknet/backups"           # Database backup directory
PG_DB="prod_db"                              # PostgreSQL database name
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"  # Log file for the current update process
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"  # Repository URL

# Create directories for logs and backups
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Redirect script output to a log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Function to create a database backup
create_database_backup() {
    echo "Creating database backup..."
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
        sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
    else
        echo "Database $PG_DB does not exist. Skipping backup."
    fi
}

# Function to cleanup the current installation while preserving important files
cleanup() {
    echo "Cleaning up the current installation..."
    [ -f "$APP_DIR/requirements.txt" ] && cp "$APP_DIR/requirements.txt" "$BACKUP_DIR"
    [ -f "$APP_DIR/app.py" ] && cp "$APP_DIR/app.py" "$BACKUP_DIR"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

# Function to clone the repository and install dependencies
setup() {
    echo "Cloning the repository and installing dependencies..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
    [ -f "$BACKUP_DIR/requirements.txt" ] && cp "$BACKUP_DIR/requirements.txt" "$APP_DIR"
    [ -f "$BACKUP_DIR/app.py" ] && cp "$BACKUP_DIR/app.py" "$APP_DIR"
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    if [ -f "requirements.txt" ]; then
        pip install -r "requirements.txt"
    else
        echo "File requirements.txt not found. Unable to install Python dependencies."
        return 1
    fi
}

# Function to restore the database from backup
restore_database() {
    echo "Restoring the database from backup..."
    if [ -f "$BACKUP_DIR/db_backup_latest.sql" ]; then
        sudo -u postgres psql -d "$PG_DB" -f "$BACKUP_DIR/db_backup_latest.sql"
    else
        echo "No database backup found. Skipping database restoration."
    fi
}

# Function to update the repository
update_repository() {
    echo "Updating the repository..."
    cd "$APP_DIR"
    git pull || {
        echo "Attempting to restore the repository due to an error..."
        git fetch --all
        git reset --hard origin/main
    }
}

# Function to activate the Python virtual environment
activate_virtualenv() {
    echo "Activating the Python virtual environment..."
    source "$VENV_DIR/bin/activate"
}

# Function to run database migrations
run_database_migration() {
    echo "Running database migrations..."
    flask db upgrade || {
        echo "Migration failed. Attempting to create a new migration..."
        flask db init
        flask db migrate
        flask db upgrade
    }
}

# Function to deactivate the Python virtual environment
deactivate_virtualenv() {
    echo "Deactivating the Python virtual environment..."
    deactivate || true
}

# Function to restart the Flask application
restart_application() {
    echo "Restarting the Flask application..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Application restarted."
}

# Main execution sequence
echo "Script execution started."
create_database_backup
cleanup
setup
restore_database
update_repository
activate_virtualenv
run_database_migration
deactivate_virtualenv
restart_application
echo "Script execution completed successfully."

# End of the script
