from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required
from werkzeug.security import generate_password_hash, check_password_hash
import os
import random
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)
CORS(app)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Setting up logging
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
login_manager = LoginManager(app)
login_manager.login_view = 'login'

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password = db.Column(db.String(80), nullable=False)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def index():
    app.logger.info('Accessed index page')
    return render_template('index.html')

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data or not all(key in data for key in ['username', 'email', 'password']):
        app.logger.error('Missing data during registration')
        return jsonify({'message': 'Missing data'}), 400

    if User.query.filter_by(email=data['email']).first():
        app.logger.error('Email already registered during registration')
        return jsonify({'message': 'Email already registered'}), 409

    hashed_password = generate_password_hash(data['password'], method='sha256')
    new_user = User(username=data['username'], email=data['email'], password=hashed_password)
    db.session.add(new_user)
    db.session.commit()
    app.logger.info('Registration successful for user %s', data['username'])
    return jsonify({'message': 'Registration successful'}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or not all(key in data for key in ['email', 'password']):
        app.logger.error('Missing data during login')
        return jsonify({'message': 'Missing data'}), 400

    user = User.query.filter_by(email=data['email']).first()
    if user and check_password_hash(user.password, data['password']):
        login_user(user)
        app.logger.info('Login successful for user %s', user.username)
        return jsonify({'message': 'Login successful', 'username': user.username}), 200

    app.logger.error('Invalid email or password during login')
    return jsonify({'message': 'Invalid email or password'}), 401

@app.route('/debug-number', methods=['GET'])
@login_required
def debug_number():
    debug_num = random.randint(1, 100)
    app.logger.info('Generated debug number: %d', debug_num)
    return jsonify({'debugNumber': debug_num})

if __name__ == '__main__':
    db.create_all()
    app.run(host='0.0.0.0', port=8000, debug=True)
