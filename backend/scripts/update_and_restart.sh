#!/bin/bash

# Initialization and strict mode
set -euo pipefail
trap 'echo "Error on line $LINENO. Exiting with code $?" >&2; exit 1' ERR

# Load environment variables
ENV_FILE="/srv/talknet/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "Environment file $ENV_FILE not found, exiting..."
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
    find "$LOG_DIR" -type f -name '*.log' -mtime +30 -exec rm {} \;
    echo "Old logs cleaned up."
}

# Reinstall PostgreSQL
reinstall_postgresql() {
    echo "Reinstalling PostgreSQL..."
    sudo apt-get remove --purge -y postgresql postgresql-contrib
    sudo rm -rf /var/lib/postgresql/

    # Get PostgreSQL version
    local version=$(apt-cache policy postgresql | grep Installed | awk '{print $2}')

    # Install PostgreSQL with the extracted version
    sudo apt-get install -y postgresql="$version" postgresql-contrib="$version"
    echo "PostgreSQL reinstalled."
}

# Initialize PostgreSQL Database Cluster
init_db_cluster() {
    # Get PostgreSQL version
    local version=$(apt-cache policy postgresql | grep Installed | awk '{print $2}')

    # Initialize PostgreSQL cluster with the extracted version
    sudo pg_dropcluster --stop "$version" main || true  # Remove default cluster if exists
    sudo pg_createcluster "$version" main --start  # Create a new cluster
    echo "PostgreSQL cluster initialized."
}

# Configure PostgreSQL to accept connections
configure_postgresql() {
    local version=$(pg_lsclusters | awk '/main/ {print $1}')
    # Replace listen_addresses and port in postgresql.conf
    sudo sed -i "/^#listen_addresses = 'localhost'/c\listen_addresses = '*'" "/etc/postgresql/$version/main/postgresql.conf"
    sudo sed -i "/^#port = 5432/c\port = 5432" "/etc/postgresql/$version/main/postgresql.conf"

    # Allow all connections in pg_hba.conf
    echo "host all all all md5" | sudo tee -a "/etc/postgresql/$version/main/pg_hba.conf"
    sudo systemctl restart postgresql
    echo "PostgreSQL configured to accept connections."
}

# Create PostgreSQL user and database
create_db_user_and_database() {
    sudo -u postgres psql -c "CREATE USER $PG_USER WITH PASSWORD '$PG_PASSWORD';"
    sudo -u postgres psql -c "CREATE DATABASE $PG_DB WITH OWNER $PG_USER;"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $PG_DB TO $PG_USER;"
    echo "Database and user created."
}

# Install required dependencies
install_dependencies() {
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip python3-venv git nginx
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

# Apply database schema
apply_schema() {
    echo "Applying database schema..."
    SCHEMA_PATH="$FLASK_APP_DIR/database/schema.sql"
    if [ -f "$SCHEMA_PATH" ]; then
        sudo -u postgres psql -d "$PG_DB" -a -f "$SCHEMA_PATH"
        echo "Schema applied from $SCHEMA_PATH."
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
    pip install -r "$FLASK_APP_DIR/requirements.txt"
    echo "Dependencies installed."
}

# Apply Flask database migrations
apply_migrations() {
    echo "Applying Flask database migrations..."
    source "$VENV_DIR/bin/activate"
    export FLASK_APP="$FLASK_APP_DIR/app.py"  # Adjust this to your Flask app's entry point

    if [ ! -d "$FLASK_APP_DIR/migrations" ]; then
        flask db init
    fi

    flask db migrate -m "Auto-generated migration."
    flask db upgrade || echo "No migrations to apply or migration failed."
}

# Restart the Flask application and Nginx
restart_services() {
    echo "Restarting Flask application and Nginx..."
    # Replace with your actual commands to restart Flask and Nginx
    pkill gunicorn || true
    cd "$FLASK_APP_DIR"
    gunicorn --bind 0.0.0.0:8000 "app:create_app()" --daemon
    sudo systemctl restart nginx
    echo "Flask application and Nginx restarted."
}

# Main logic
rotate_logs
install_dependencies
reinstall_postgresql
init_db_cluster
configure_postgresql
create_db_user_and_database
test_db_connection || { echo "Database configuration issue. Aborting."; exit 1; }
backup_db
clone_update_repo
setup_venv
apply_schema
apply_migrations
restart_services

echo "Deployment completed: $(date)"
