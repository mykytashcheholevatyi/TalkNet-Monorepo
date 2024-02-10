#!/bin/bash

# Set strict execution mode and error handling
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2; exit 1' ERR

# Configuration variables
LOG_DIR="/srv/talknet/var/log"
STATS_DIR="/srv/talknet/var/stats"
mkdir -p "$LOG_DIR" "$STATS_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
STATS_FILE="$STATS_DIR/deploy_stats_$(date +%Y-%m-%d_%H-%M-%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "Script execution started: $(date)"

# Rotate and archive old Flask logs
FLASK_LOG_FILE="flask_app.log"
if [ -f "$FLASK_LOG_FILE" ]; then
    mv "$FLASK_LOG_FILE" "$LOG_DIR/flask_app_$(date +%Y-%m-%d_%H-%M-%S).log"
fi

# Function to install required packages
install_dependencies() {
    echo "Installing required packages..."
    DEPS="python3 python3-pip python3-venv git postgresql postgresql-contrib nginx"
    for dep in $DEPS; do
        if ! dpkg -l | grep -qw $dep; then
            echo "Installing $dep..."
            sudo apt-get install -y $dep
        else
            echo "$dep is already installed."
        fi
    done
}

# Function to setup PostgreSQL
setup_postgresql() {
    echo "Setting up PostgreSQL..."
    PG_USER="your_username"
    PG_DB="prod_db"
    PG_PASSWORD="your_password"
    if ! sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1; then
        echo "Creating PostgreSQL user $PG_USER..."
        sudo -u postgres createuser -P "$PG_USER"
    else
        echo "PostgreSQL user $PG_USER already exists."
    fi
    if ! sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1; then
        echo "Creating PostgreSQL database $PG_DB..."
        sudo -u postgres createdb -O "$PG_USER" "$PG_DB"
    else
        echo "PostgreSQL database $PG_DB already exists."
    fi
}

# Function to clone or update repository
clone_or_update_repository() {
    echo "Cloning or updating repository..."
    REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
    APP_DIR="/srv/talknet"
    if [ ! -d "$APP_DIR" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR"
        git stash
        git pull --rebase
        git stash pop || true
    fi
}

# Function to setup Python virtual environment and install dependencies
setup_python_environment() {
    echo "Setting up Python virtual environment..."
    VENV_DIR="$APP_DIR/backend/auth-service/venv"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Function to backup database and collect stats
backup_database_and_collect_stats() {
    echo "Creating database backup and collecting stats..."
    BACKUP_DIR="/srv/talknet/backups"
    mkdir -p "$BACKUP_DIR"
    sudo -u postgres pg_dump "$PG_DB" > "$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
    # Collect system stats
    echo "Collecting system stats..." > "$STATS_FILE"
    top -b -n 1 >> "$STATS_FILE"
    df -h >> "$STATS_FILE"
    free -m >> "$STATS_FILE"
}

# Function to push changes to repository
push_to_repository() {
    echo "Checking for changes..."
    cd "$APP_DIR"
    # Check for changes in files excluding the backups directory
    if git status --porcelain | grep -v "^?? backups/" | grep -v "\[LOGS_UPDATE\]"; then
        echo "Pushing changes to Git repository..."
        git add .
        git commit -m "Automatic database backup: $(date) [LOGS_UPDATE]"
        git push origin main
        echo "Changes pushed to Git repository."
    else
        echo "Changes only involve logs. Skipping push to Git repository."
    fi
}

# Function to start Flask application
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
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database_and_collect_stats
push_to_repository
start_flask_application

echo "Script execution completed successfully: $(date)"
