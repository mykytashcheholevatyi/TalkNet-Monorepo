#!/bin/bash

# Перейти в директорию монорепозитория
cd /var/www/TalkNet-Monorepo

# Обновить код из монорепозитория
git pull

# Перейти в директорию проекта reddit-clone
cd reddit-clone

# Установить зависимости
npm install

# Перезапустить проект (предполагается, что вы используете npm start)
npm restart
