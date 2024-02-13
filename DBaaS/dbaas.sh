#!/bin/bash

# Определение основных переменных
DBAAS_DIR="/srv/dbaas"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo.git"
BACKUP_DIR="$DBAAS_DIR/backups"
LOG_DIR="$DBAAS_DIR/logs"
LOG_FILE="$LOG_DIR/dbaas.log"
DOCKER_COMPOSE_FILE="$DBAAS_DIR/docker-compose.yml"

# Название и пользователь базы данных
DB_CONTAINER_NAME="postgres_container"
DB_USER="postgres"

# Функция для записи логов
log_message() {
    mkdir -p "$LOG_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Установка Docker и Docker Compose
install_docker() {
    log_message "Установка Docker и Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_message "Docker и Docker Compose установлены."
}

# Создание бэкапов и их отправка в репозиторий
backup_and_push() {
    log_message "Создание бэкапов и отправка их в репозиторий..."
    
    # Создание бэкапа базы данных
    TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")
    DB_BACKUP_PATH="$BACKUP_DIR/db_backup_$TIMESTAMP.sql"
    sudo docker exec "$DB_CONTAINER_NAME" pg_dumpall -c -U "$DB_USER" > "$DB_BACKUP_PATH"

    # Добавление бэкапа в репозиторий и отправка
    git add "$DB_BACKUP_PATH"
    git commit -m "Database backup on $TIMESTAMP"
    git push origin main

    log_message "Бэкапы созданы и отправлены в репозиторий."
}

# Настройка и запуск DBaaS
setup_dbaas() {
    log_message "Настройка и запуск DBaaS..."
    sudo mkdir -p "$BACKUP_DIR"
    if [ -f "$DOCKER_COMPOSE_FILE" ]; then
        sudo docker-compose -f "$DOCKER_COMPOSE_FILE" up -d
        log_message "DBaaS запущен."
    else
        log_message "Файл docker-compose.yml не найден."
    fi
}

# Основная логика скрипта
case "$1" in
    setup)
        log_message "Начало настройки DBaaS..."
        install_docker
        setup_dbaas
        backup_and_push
        log_message "Настройка DBaaS завершена."
        ;;
    backup)
        backup_and_push
        ;;
    *)
        echo "Использование: $0 {setup|backup}"
        exit 1
        ;;
esac
