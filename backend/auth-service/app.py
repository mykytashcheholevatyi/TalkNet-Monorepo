from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash
import os
import random
import string
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)
CORS(app)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://username:password@localhost/dbname'  # Обновите эту строку
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Настройка логирования
def setup_logging(app):
    if not app.debug:
        file_handler = RotatingFileHandler('flask_app.log', maxBytes=10240, backupCount=10)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'
        ))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)
        app.logger.setLevel(logging.INFO)

setup_logging(app)

db = SQLAlchemy(app)
migrate = Migrate(app, db)  # Инициализация Flask-Migrate

login_manager = LoginManager(app)
login_manager.login_view = 'login'

# Модели
class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Генерация случайной строки
def random_string(length=10):
    """Генерация случайной строки фиксированной длины."""
    letters = string.ascii_letters
    return ''.join(random.choice(letters) for i in range(length))

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/test-db', methods=['GET'])
def test_db():
    try:
        username = random_string(5)
        email = f"{random_string(5)}@example.com"
        password = 'testpassword'
        hashed_password = generate_password_hash(password, method='sha256')

        new_user = User(username=username, email=email, password_hash=hashed_password)
        db.session.add(new_user)
        db.session.commit()

        app.logger.info(f"Тестовый пользователь создан с именем пользователя: {username}, email: {email}")
        return jsonify({'message': f'Тестовый пользователь создан с именем пользователя: {username}, email: {email}'}), 201
    except Exception as e:
        app.logger.error('Ошибка при создании тестового пользователя: %s', str(e))
        return jsonify({'message': 'Внутренняя ошибка сервера'}), 500

if __name__ == '__main__':
    db.create_all()
    app.run(host='0.0.0.0', port=8000, debug=True)
