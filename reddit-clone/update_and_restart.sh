#!/bin/bash

# Define variables for paths
MONOREPO_DIR="/var/www/TalkNet-Monorepo"
FRONTEND_DIR="/var/www/reddit-clone"
BACKUP_DIR="/var/www/reddit-clone-backup"

# Ensure script is run as root
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root."
  exit 1
fi

# Check if the monorepo directory exists
if [ ! -d "$MONOREPO_DIR" ]; then
  echo "Monorepo directory '$MONOREPO_DIR' does not exist."
  exit 1
fi

# Check if the frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
  echo "Frontend directory '$FRONTEND_DIR' does not exist."
  exit 1
fi

# Ensure no process is using port 3000
if lsof -t -i:3000; then
  echo "A process is already using port 3000. Please stop it and run the script again."
  exit 1
fi

# Navigate to the monorepo directory and update from the repository
cd "$MONOREPO_DIR" || exit
if ! git pull; then
  echo "Failed to update from the repository. Exiting."
  exit 1
fi

# Create a backup of the current frontend directory
if [ -d "$FRONTEND_DIR" ]; then
  mv "$FRONTEND_DIR" "$BACKUP_DIR"
fi

# Copy the updated frontend from the monorepo
cp -r "$MONOREPO_DIR/reddit-clone" "$FRONTEND_DIR" || {
  echo "Failed to copy frontend files. Restoring backup."
  mv "$BACKUP_DIR" "$FRONTEND_DIR"
  exit 1
}

# Navigate to the frontend directory
cd "$FRONTEND_DIR" || exit

# Install npm dependencies
if ! npm install; then
  echo "Failed to install npm dependencies. Restoring backup."
  mv "$BACKUP_DIR" "$FRONTEND_DIR"
  exit 1
fi

# Start the application
npm start
