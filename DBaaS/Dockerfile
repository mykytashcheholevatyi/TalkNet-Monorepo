# Использование официального образа PostgreSQL как базового
FROM postgres:latest

# Установка необходимых переменных окружения
ENV POSTGRES_DB=db_name
ENV POSTGRES_USER=user
ENV POSTGRES_PASSWORD=password

# Копирование скриптов инициализации, если они есть
COPY ./init-scripts /docker-entrypoint-initdb.d/
