command = '/srv/talknet/venv/bin/gunicorn'
pythonpath = '/srv/talknet/backend'
bind = '0.0.0.0:8000'  # Убедитесь, что этот порт свободен
workers = 3
user = 'www-data'
