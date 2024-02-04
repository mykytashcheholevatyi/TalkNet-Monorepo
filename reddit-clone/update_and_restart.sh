#!/bin/bash

# Перейти в директорию монорепозитория
cd /var/www/TalkNet-Monorepo

# Обновить код из монорепозитория
git pull

# Создать бекап текущей версии проекта (если необходимо)
# sudo mv /var/www/reddit-clone /var/www/reddit-clone-backup

# Переместить папку с React-проектом из монорепозитория в текущую директорию
sudo cp -r reddit-clone /var/www/

# Перейти в директорию проекта reddit-clone
cd /var/www/reddit-clone

# Установить зависимости
npm install

# Перезапустить проект (предполагается, что вы используете npm start)
npm restart
