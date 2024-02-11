#!/bin/bash

# Set strict execution mode, error handling, and traceability
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2; exit 1' ERR

# Load environment variables
if [ -f /srv/talknet/.env ]; then
    export $(cat /srv/talknet/.env | xargs)
    source /srv/talknet/.env
else
    echo "Environment file not found, exiting..."
    exit 1
fi

# Define directory paths
LOG_DIR="/srv/talknet/var/log"
STATS_DIR="/srv/talknet/var/stats"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
VENV_DIR="$APP_DIR/backend/auth-service/venv"
SCHEMA_PATH="$APP_DIR/backend/auth-service/database/forum_schema.sql"

# Ensure required directories exist
mkdir -p "$LOG_DIR" "$STATS_DIR" "$BACKUP_DIR"

# Redirect stdout and stderr to log file
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Script execution started: $(date)"

# Rotate Flask logs
rotate_flask_logs() {
    echo "Rotating and archiving old Flask logs..."
    find "$LOG_DIR" -name 'flask_app*.log' -mtime +30 -exec rm {} \;
}

# Install dependencies
install_dependencies() {
    echo "Installing necessary packages..."
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git postgresql postgresql-contrib nginx
}

# Setup PostgreSQL
setup_postgresql() {
    echo "Checking PostgreSQL user and database..."
    DB_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$PG_DB'")
    USER_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$PG_USER'")

    if [ "$DB_EXISTS" = "1" ]; then
        echo "Database $PG_DB already exists"
    else
        echo "Creating database $PG_DB..."
        sudo -u postgres psql -c "CREATE DATABASE $PG_DB OWNER $PG_USER;"
    fi

    if [ "$USER_EXISTS" = "1" ]; then
        echo "User $PG_USER already exists"
    else
        echo "Creating user $PG_USER..."
        sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    fi

    echo "Applying database schema..."
    sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH" || echo "Warning: Problem applying database schema."
}

# Clone or update repository
clone_or_update_repository() {
    echo "Cloning or updating repository..."
    if [ ! -d "$APP_DIR/.git" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR" && git stash && git pull --rebase && git stash pop || true
    fi
}

# Setup Python environment
setup_python_environment() {
    echo "Setting up Python virtual environment and installing dependencies..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Backup database and collect stats
backup_database_and_collect_stats() {
    echo "Creating database backup and collecting stats..."
    BACKUP_FILE="$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    STATS_FILE="$STATS_DIR/deploy_stats_$(date +%Y-%m-%d_%H-%M-%S).log"
    top -b -n 1 >> "$STATS_FILE"
    df -h >> "$STATS_FILE"
    free -m >> "$STATS_FILE"
}

# Apply database migrations
apply_database_migrations() {
    echo "Applying database migrations..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    cd "$APP_DIR/backend/auth-service" && flask db upgrade || echo "Warning: Failed to apply database migrations."
}

# Push changes to repository
push_to_repository() {
    echo "Checking for changes and pushing to repository..."
    cd "$APP_DIR"
    if git status --porcelain | grep -v "^??"; then
        git add .
        git commit -m "Automated database backup: $(date)"
        git push origin main
        echo "Changes pushed to repository."
    else
        echo "No significant changes to push."
    fi
}

# Start Flask application
start_flask_application() {
    echo "Starting Flask application..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon
}

# Restart NGINX
restart_nginx() {
    echo "Restarting NGINX..."
    sudo systemctl restart nginx
}

# Main sequence of execution
main() {
    rotate_flask_logs
    install_dependencies
    setup_postgresql
    clone_or_update_repository
    setup_python_environment
    backup_database_and_collect_stats
    apply_database_migrations
    push_to_repository
    start_flask_application
    restart_nginx
    echo "Script execution completed: $(date)"
}

# Execute main function
main
