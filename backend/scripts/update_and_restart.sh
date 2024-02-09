#!/bin/bash

# Set strict execution mode and error handling
set -euo pipefail
trap 'echo "An error occurred on line $LINENO. Exiting with error code $?" >&2' ERR

# Define configuration variables
LOG_DIR="/srv/talknet/var/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/deploy.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Script execution started: $(date)"

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
    PG_USER="your_username"
    PG_DB="prod_db"
    PG_PASSWORD="your_password"
    echo "Setting up PostgreSQL..."
    sudo -u postgres psql -c "SELECT 1 FROM pg_user WHERE usename = '$PG_USER';" | grep -q 1 || sudo -u postgres createuser -P "$PG_USER"
    sudo -u postgres psql -c "SELECT 1 FROM pg_database WHERE datname = '$PG_DB';" | grep -q 1 || sudo -u postgres createdb -O "$PG_USER" "$PG_DB"
}

# Function to clone or update the repository
clone_or_update_repository() {
    REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
    APP_DIR="/srv/talknet"
    echo "Cloning or updating the repository..."
    if [ ! -d "$APP_DIR" ]; then
        git clone "$REPO_URL" "$APP_DIR"
    else
        cd "$APP_DIR" && git pull
    fi
}

# Function to setup Python virtual environment and install dependencies
setup_python_environment() {
    VENV_DIR="$APP_DIR/backend/auth-service/venv"
    echo "Setting up Python environment..."
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
    fi
    source "$VENV_DIR/bin/activate"
    echo "Installing Python dependencies..."
    pip install --upgrade pip
    pip install -r "$APP_DIR/backend/auth-service/requirements.txt"
}

# Function to backup the database
backup_database() {
    BACKUP_DIR="/srv/talknet/backups"
    mkdir -p "$APP_DIR/$BACKUP_DIR"
    echo "Creating database backup..."
    sudo -u postgres pg_dump "$PG_DB" > "$APP_DIR/$BACKUP_DIR/$PG_DB-$(date +%Y-%m-%d_%H-%M-%S).sql"
}

# Function to start the Flask application
start_flask_application() {
    export FLASK_APP="$APP_DIR/backend/auth-service/app.py"
    export FLASK_ENV=production
    export DATABASE_URL="postgresql://$PG_USER:$PG_PASSWORD@localhost/$PG_DB"
    echo "Starting the Flask application..."
    pkill gunicorn || true
    gunicorn --bind 0.0.0.0:8000 app:app --chdir "$APP_DIR/backend/auth-service" --daemon --log-file="$LOG_DIR/gunicorn.log" --access-logfile="$LOG_DIR/access.log"
    echo "Flask application started."
}

# Main execution sequence
install_dependencies
setup_postgresql
clone_or_update_repository
setup_python_environment
backup_database
start_flask_application

echo "Script execution completed successfully: $(date)"
