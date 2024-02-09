#!/bin/bash

# Set strict execution mode and error handling
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?"' ERR

# Initial message indicating the start of the process
echo "Starting full cleanup, update, and restoration of the project: $(date)"

# Define configuration variables
APP_DIR="/srv/talknet/backend/auth-service"  # Application directory path
VENV_DIR="$APP_DIR/venv"                    # Python virtual environment directory
LOG_DIR="/var/log/talknet"                   # Log directory
BACKUP_DIR="/srv/talknet/backups"            # Database backups directory
REQS_BACKUP_DIR="/tmp"                       # Temporary directory for requirements.txt backup
PG_DB="prod_db"                              # PostgreSQL database name
LOG_FILE="$LOG_DIR/update-$(date +%Y-%m-%d_%H-%M-%S).log"  # Log file for the current update process
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"  # Repository URL
MAX_ATTEMPTS=3                               # Maximum number of attempts for retryable operations
ATTEMPT=1                                    # Initial attempt counter

# Create directories for logs and backups
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

# Redirect script output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

# Backup the database
create_database_backup() {
    echo "Creating a backup of the database..."
    if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$PG_DB"; then
        sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/db_backup_$(date +%Y-%m-%d_%H-%M-%S).sql"
    else
        echo "Database $PG_DB does not exist. Skipping backup."
    fi
}

# Clean the current installation while preserving important files
cleanup() {
    echo "Cleaning the current installation..."
    # Preserve the existing requirements.txt and app.py if they exist
    [ -f "$APP_DIR/requirements.txt" ] && cp "$APP_DIR/requirements.txt" "$REQS_BACKUP_DIR"
    [ -f "$APP_DIR/app.py" ] && cp "$APP_DIR/app.py" "$REQS_BACKUP_DIR"
    rm -rf "$APP_DIR"
    mkdir -p "$APP_DIR"
}

# Clone the repository and install dependencies
setup() {
    echo "Cloning the repository and installing dependencies..."
    git clone "$REPO_URL" "$APP_DIR"
    cd "$APP_DIR"
    # Restore the preserved requirements.txt and app.py
    [ -f "$REQS_BACKUP_DIR/requirements.txt" ] && cp "$REQS_BACKUP_DIR/requirements.txt" "$APP_DIR"
    [ -f "$REQS_BACKUP_DIR/app.py" ] && cp "$REQS_BACKUP_DIR/app.py" "$APP_DIR"
    # Set up a Python virtual environment
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    # Check if the requirements.txt exists before installing
    if [ -f "requirements.txt" ]; then
        pip install -r "requirements.txt"
    else
        echo "requirements.txt not found. Cannot install Python dependencies."
        return 1
    fi
}

# Optionally restore the database from a backup
restore_database() {
    echo "Restoring the database from a backup..."
    # This should contain the commands to restore the database if necessary
}

# Update the repository
update_repository() {
    echo "Fetching updates from the repository..."
    cd "$APP_DIR"
    git pull || {
        echo "Attempting to recover the repository due to an error..."
        git fetch --all
        git reset --hard origin/main
    }
}

# Activate the virtual environment
activate_virtualenv() {
    echo "Activating the virtual environment..."
    source "$VENV_DIR/bin/activate"
}

# Install Python packages
install_python_packages() {
    echo "Installing Python packages..."
    pip install --upgrade pip
    pip install -r "requirements.txt"
}

# Run database migrations
run_database_migration() {
    echo "Running database migrations..."
    flask db upgrade || {
        echo "Migration failed. Attempting to create a new migration..."
        flask db migrate
        flask db upgrade
    }
}

# ... previous code ...

# Deactivate the virtual environment
deactivate_virtualenv() {
    echo "Deactivating the virtual environment..."
    deactivate || true  # Deactivating should not cause the script to fail if not active
}

# Restart the application
restart_application() {
    echo "Restarting the application..."
    # Here you should add the command to start your application, for example using gunicorn
    # Replace 'app:app' with your actual application object if it's different
    pkill gunicorn || true  # Ignore errors if gunicorn is not running
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Application restarted."
}

# Main execution sequence
echo "Script execution started."
create_database_backup
cleanup
setup
# Optionally call restore_database if you have implemented it
# restore_database
update_repository
activate_virtualenv
install_python_packages
run_database_migration
deactivate_virtualenv
restart_application
echo "Script execution completed."

# End of script
