#!/bin/bash

# Конфигурация
dbaas_dir="/srv/dbaas"
backup_dir="$dbaas_dir/db_backups"  # Директория для бэкапов
log_file="$dbaas_dir/dbaas_logs/dbaas.log"  # Файл для логирования
db_container_name="forum-db"  # Имя контейнера с БД
git_repo_url="https://github.com/mykytashch/TalkNet-Monorepo.git"  # URL вашего Git репозитория
git_clone_dir="$dbaas_dir"  # Директория для клонирования репозитория
sql_update_path="DBaaS/updates"  # Путь к обновлениям SQL внутри репозитория
docker_compose_file="DBaaS/docker-compose.yml"  # Путь к файлу docker-compose в репозитории

# Создание необходимых директорий
sudo mkdir -p "$backup_dir"
sudo mkdir -p "$(dirname "$log_file")"

# Функция для клонирования или обновления репозитория
clone_or_update_repo() {
  if [ ! -d "$git_clone_dir/.git" ]; then
    echo "Клонирование репозитория..."
    sudo git clone "$git_repo_url" "$git_clone_dir"
  else
    echo "Обновление репозитория..."
    (cd "$git_clone_dir" && sudo git pull)
  fi
}

# Функция для установки Docker и Docker Compose
install_docker() {
  echo "Установка Docker и Docker Compose..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  sudo apt-get update
  sudo apt-get install -y docker-ce
  sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

# Функция для запуска и настройки PostgreSQL с использованием Docker Compose
setup_postgres() {
  sudo cp "$git_clone_dir/$docker_compose_file" "$dbaas_dir/docker-compose.yml"
  (cd "$dbaas_dir" && sudo docker-compose up -d)
}

# Основная логика скрипта
case "$1" in
  setup)
    clone_or_update_repo
    install_docker
    setup_postgres
    ;;
  *)
    echo "Использование: $0 setup"
    exit 1
    ;;
esac
