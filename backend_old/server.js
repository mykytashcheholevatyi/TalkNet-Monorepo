#!/bin/bash

# Настройка переменных
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo"
BACKEND_DIR="/srv/talknet/backend"
DB_DIR="/var/lib/talknet/mongodb"
LOG_DIR="/var/log/talknet/backend"
DB_NAME="talknetDB"
MONGO_USER="talknetAdmin"
MONGO_PASS="SecurePa$$w0rd"

# Функция для проверки и установки MongoDB
install_mongodb() {
    if ! command -v mongod &> /dev/null; then
        echo "MongoDB не установлена. Установка MongoDB..."
        wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
        echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
        sudo apt-get update
        sudo apt-get install -y mongodb-org
        echo "MongoDB установлена."
    else
        echo "MongoDB уже установлена."
    fi

    # Запуск MongoDB и включение автозапуска
    sudo systemctl start mongod
    sudo systemctl enable mongod
}

# Функция для настройки безопасности MongoDB
configure_mongodb_security() {
    # Создание пользователя администратора и включение авторизации
    mongo <<EOF
use admin
db.createUser({
  user: '$MONGO_USER',
  pwd: '$MONGO_PASS',
  roles: [{ role: 'userAdminAnyDatabase', db: 'admin' }, 'readWriteAnyDatabase']
})
EOF

    # Включение авторизации в конфигурационном файле MongoDB
    sudo sed -i '/  security:/a\  authorization: enabled' /etc/mongod.conf
    sudo systemctl restart mongod
}

# Функция для клонирования или обновления репозитория бэкенда
update_backend_repo() {
    # Создание необходимых директорий
    sudo mkdir -p $BACKEND_DIR $DB_DIR $LOG_DIR
    sudo chown -R `whoami` $BACKEND_DIR $DB_DIR $LOG_DIR

    # Клонирование или обновление репозитория
    if [ ! -d "$BACKEND_DIR/.git" ]; then
        git clone $REPO_URL $BACKEND_DIR
    else
        cd $BACKEND_DIR
        git pull
    fi
}

# Функция для установки зависимостей и запуска бэкенда
deploy_backend() {
    cd $BACKEND_DIR/backend  # Уточните путь, если структура в репозитории другая
    npm install

    # Перезапуск Node.js сервера
    pkill -f 'node server.js'
    nohup node server.js > $LOG_DIR/server.log 2>&1 &
}

# Функция для проверки и создания базы данных, если необходимо
create_database_if_needed() {
    mongo -u $MONGO_USER -p $MONGO_PASS --authenticationDatabase admin <<EOF
use $DB_NAME
db.createCollection("initCollection")
db.initCollection.drop()
EOF
}

# Выполнение функций
install_mongodb
configure_mongodb_security
update_backend_repo
deploy_backend
create_database_if_needed

echo "Бэкенд успешно развернут и настроен."
