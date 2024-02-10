#!/bin/bash

# Set strict execution mode, error handling, and traceability
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2; exit 1' ERR

# Load environment variables
if [ -f /srv/talknet/.env ]; then
    export $(cat /srv/talknet/.env | xargs)
fi

# Define directory paths
LOG_DIR="/srv/talknet/var/log"
STATS_DIR="/srv/talknet/var/stats"
BACKUP_DIR="/srv/talknet/backups"
APP_DIR="/srv/talknet"
VENV_DIR="$APP_DIR/backend/auth-service/venv"

# Ensure required directories exist
mkdir -p "$LOG_DIR" "$STATS_DIR" "$BACKUP_DIR"

# Redirect stdout and stderr to log file
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Script execution started: $(date)"

# Rotate and archive old Flask logs
rotate_flask_logs() {
    echo "Rotating and archiving old Flask logs..."
    find "$LOG_DIR" -name 'flask_app*.log' -mtime +30 -exec rm {} \;  # Deletes Flask logs older than 30 days
}

# Install required packages if not already installed
install_dependencies() {
    echo "Installing required packages..."
    DEPS="python3 python3-pip python3-venv git postgresql postgresql-contrib nginx"
    sudo apt-get update
    sudo apt-get install -y $DEPS
}

# Setup PostgreSQL if not already configured
setup_postgresql() {
    echo "Ensuring PostgreSQL user and database are set up..."
    sudo -u postgres psql -c "SELECT 1 FROM pg_roles WHERE rolname = '$PG_USER';" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE ROLE $PG_USER WITH LOGIN PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || \
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
}


# Clone or update repository
clone_or_update_repository() {
    echo "Ensuring the latest version of the repository is cloned..."
    if [ ! -d "$APP_DIR/.git" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR"
        git stash
        git pull --rebase
        git stash pop || true
    fi
}

# Setup Python virtual environment and install dependencies
setup_python_environment() {
    echo "Setting up Python virtual environment and installing dependencies..."
    python3 -m venv "$VENV_DIR"
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Backup database and collect system stats
backup_database_and_collect_stats() {
    echo "Creating database backup and collecting system stats..."
    BACKUP_FILE="$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_FILE"
    echo "Database backup saved to $BACKUP_FILE"
    STATS_FILE="$STATS_DIR/deploy_stats_$(date +%Y-%m-%d_%H-%M-%S).log"
    echo "Collecting system stats to $STATS_FILE"
    top -b -n 1 >> "$STATS_FILE"
    df -h >> "$STATS_FILE"
    free -m >> "$STATS_FILE"
}

# Apply database migrations with Flask-Migrate
apply_database_migrations() {
    echo "Applying database migrations with Flask-Migrate..."
    source "$VENV_DIR/bin/activate"
    cd "$APP_DIR/backend/auth-service"
    # Check if the migrations directory exists, if not, initialize Flask-Migrate
    if [ ! -d "migrations" ]; then
        echo "Initializing Flask-Migrate..."
        flask db init
    fi
    # Now that the migrations directory is guaranteed to exist, generate new migrations and apply them
    echo "Generating and applying migrations..."
    flask db migrate -m "Generated migration"
    flask db upgrade
    echo "Database migrations applied successfully."
}


# Push changes to repository if there are any
push_to_repository() {
    echo "Checking for changes and pushing to Git repository..."
    cd "$APP_DIR"
    git status --porcelain | grep -v "^?? backups/" | grep -v "\[LOGS_UPDATE\]" && {
        git add .
        git commit -m "Automatic database backup: $(date) [LOGS_UPDATE]"
        git push origin main
        echo "Changes pushed to Git repository."
    } || echo "No significant changes to push."
}

# Start Flask application
start_flask_application() {
    echo "Starting Flask application..."
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Flask application started."
}

# Main execution sequence
rotate_flask_logs
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database_and_collect_stats
apply_database_migrations
push_to_repository
start_flask_application

echo "Script execution completed successfully: $(date)"
