#!/bin/bash

# Определение основных переменных
DBAAS_DIR="/srv/dbaas"
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo.git"
BACKUP_DIR="$DBAAS_DIR/backups"
LOG_DIR="$DBAAS_DIR/logs"
LOG_FILE="$LOG_DIR/dbaas.log"

# Удаление существующей директории и клонирование репозитория
initialize_repo() {
    sudo rm -rf "$DBAAS_DIR"
    echo "Клонирование репозитория $REPO_URL в $DBAAS_DIR..."
    sudo git clone "$REPO_URL" "$DBAAS_DIR"
    sudo mkdir -p "$BACKUP_DIR" "$LOG_DIR"
}

# Функция для записи логов
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Функция для установки Docker и Docker Compose
install_docker() {
    log_message "Установка Docker и Docker Compose..."
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    log_message "Docker и Docker Compose установлены."
}

# Функция для настройки и запуска DBaaS
setup_dbaas() {
    log_message "Настройка и запуск DBaaS..."
    if [ -f "$DBAAS_DIR/DBaaS/docker-compose.yml" ]; then
        (cd "$DBAAS_DIR/DBaaS" && sudo docker-compose up -d)
        log_message "DBaaS запущен."
    else
        log_message "Файл docker-compose.yml не найден."
    fi
}

# Основная логика скрипта
case "$1" in
    setup)
        log_message "Начало настройки DBaaS..."
        initialize_repo
        install_docker
        setup_dbaas
        log_message "Настройка DBaaS завершена."
        ;;
    *)
        echo "Использование: $0 setup"
        exit 1
        ;;
esac
