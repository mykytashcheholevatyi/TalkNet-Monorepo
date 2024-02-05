#!/bin/bash

# Настройка переменных
REPO_URL="your_monorepo_git_url.git"
PROJECT_DIR="/path/to/monorepo/backend"
DB_DIR="/path/to/mongodb/data"
LOG_DIR="/path/to/backend/logs"
DB_NAME="your_database_name"

# Клонирование или обновление репозитория
if [ ! -d "$PROJECT_DIR" ]; then
  git clone $REPO_URL $PROJECT_DIR
  cd $PROJECT_DIR/backend # Переход в поддиректорию бэкенда, если она есть
else
  cd $PROJECT_DIR
  git pull $REPO_URL
fi

# Установка зависимостей бэкенда
npm install

# Запуск MongoDB
mkdir -p $DB_DIR
mkdir -p $LOG_DIR
mongod --dbpath $DB_DIR --logpath $LOG_DIR/mongodb.log --fork

# Проверка наличия базы данных и ее создание при необходимости
echo "use $DB_NAME" | mongo --quiet
echo "База данных $DB_NAME доступна."

# Запуск сервера Node.js в фоновом режиме
nohup node server.js > $LOG_DIR/server.log &

echo "Бэкенд и MongoDB успешно развернуты."
