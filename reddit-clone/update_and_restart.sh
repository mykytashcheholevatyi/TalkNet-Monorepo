#!/bin/bash

cd /var/www/TalkNet-Monorepo
git pull
kill $(lsof -t -i:3000) 2> /dev/null
sudo mv /var/www/reddit-clone /var/www/reddit-clone-backup
sudo cp -r reddit-clone /var/www/
cd /var/www/reddit-clone
npm install
npm start
