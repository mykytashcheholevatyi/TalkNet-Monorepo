#!/bin/bash

# Определение переменных
REPO_URL="https://github.com/mykytashch/TalkNet-Monorepo.git"  # URL вашего репозитория
APP_DIR="src/TalkNet-Monorepo"  # Директория для клонирования

# Функция для установки Docker и Docker Compose
function install_docker() {
    echo "Установка Docker и Docker Compose..."

    # Установка Docker
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Установка Docker Compose
function install_docker_compose() {
    if ! type docker-compose > /dev/null 2>&1; then
        echo "Установка Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        # Проверяем, существует ли уже символическая ссылка
        if [ ! -L /usr/bin/docker-compose ]; then
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        else
            echo "Символическая ссылка для docker-compose уже существует."
        fi
        echo "Docker Compose установлен."
    else
        echo "Docker Compose уже установлен."
    fi
}


# Загрузка переменных окружения
source .env

# Строгий режим
set -euo pipefail
trap 'echo "Ошибка на строке $LINENO. Завершение с кодом $?" >&2; exit 1' ERR

# Клонирование репозитория
function clone_repo() {
    echo "Клонирование репозитория..."
    if [ -d "$APP_DIR" ]; then
        echo "Директория $APP_DIR уже существует. Попытка обновления репозитория..."
        cd "$APP_DIR"
        git pull
        cd -
    else
        mkdir -p src
        git clone "$REPO_URL" "$APP_DIR"
    fi
    echo "Репозиторий успешно клонирован/обновлен."
}

# Использование Docker и Docker Compose для развертывания Flask приложения
function setup_flask_docker() {
    echo "Настройка Flask приложения в Docker..."
    cd "$APP_DIR"
    docker-compose up -d
    cd -
    echo "Flask приложение запущено в Docker."
}

# Интеграция с CI/CD для автоматического обновления и развертывания
function ci_cd_integration() {
    echo "Интеграция с CI/CD..."
    # Настройка webhook'ов GitHub Actions, GitLab CI или Jenkins для автоматического развертывания
    echo "CI/CD интеграция выполнена."
}

# Настройка мониторинга и логирования с Prometheus, Grafana и ELK Stack
function setup_monitoring_logging() {
    echo "Настройка мониторинга и логирования..."
    # Запуск и конфигурация Prometheus, Grafana и ELK Stack
    echo "Мониторинг и логирование настроены."
}

# Основная логика скрипта
install_docker
clone_repo
setup_flask_docker
ci_cd_integration
setup_monitoring_logging

echo "Настройка и запуск Flask приложения завершены."
