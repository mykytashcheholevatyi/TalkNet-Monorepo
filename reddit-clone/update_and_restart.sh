#!/bin/bash

# Перейти в директорию монорепозитория
cd /var/www/TalkNet-Monorepo

# Сбросить все локальные изменения и заменить их содержимым репозитория
git reset --hard origin/main

# Обновить код из монорепозитория
git pull

# Перейти в директорию проекта reddit-clone
cd reddit-clone

# Установить зависимости
npm install

# Построить production сборку
npm run build

# Завершить процесс, использующий порт 3000 (если он есть)
kill $(lsof -t -i:3000)

# Запустить React-проект на порту 3000
npm start
