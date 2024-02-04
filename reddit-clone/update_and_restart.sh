#!/bin/bash

# Define paths
MONOREPO_DIR="/var/www/TalkNet-Monorepo"
FRONTEND_DIR="/var/www/reddit-clone"

# Ensure the frontend directory exists
if [ ! -d "$FRONTEND_DIR" ]; then
  echo "Frontend directory does not exist. Cloning..."
  git clone https://github.com/mykytashch/TalkNet-Monorepo.git "$FRONTEND_DIR"
else
  echo "Frontend directory already exists. Updating..."
  # Navigate to the frontend directory
  cd "$FRONTEND_DIR" || exit

  # Pull the latest changes from the monorepo
  git -C "$MONOREPO_DIR" pull

  # Copy the updated frontend from the monorepo to the parent directory
  cp -r "$MONOREPO_DIR/reddit-clone"/* ..

  echo "Frontend updated successfully."
fi

# Navigate to the frontend directory
cd "$FRONTEND_DIR" || exit

# Install npm dependencies
npm install

# Start the application
npm start
