from flask import Flask, request, jsonify, render_template
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required
from flask_migrate import Migrate
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.exceptions import HTTPException
import os
import random
import logging
from logging.handlers import RotatingFileHandler

app = Flask(__name__)
CORS(app)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://username:password@localhost/dbname'  # Update this line
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
migrate = Migrate(app, db)  # Initialize Flask-Migrate

login_manager = LoginManager(app)
login_manager.login_view = 'login'

# Models
class User(UserMixin, db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(255), unique=True, nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())
    language = db.Column(db.String(50), nullable=False)
    is_seller = db.Column(db.Boolean, default=False)

class Post(db.Model):
    __tablename__ = 'posts'
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    title = db.Column(db.String(255), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())
    language = db.Column(db.String(50), nullable=False)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'))

class Comment(db.Model):
    __tablename__ = 'comments'
    id = db.Column(db.Integer, primary_key=True)
    post_id = db.Column(db.Integer, db.ForeignKey('posts.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    content = db.Column(db.Text, nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())

class Category(db.Model):
    __tablename__ = 'categories'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text)

class Product(db.Model):
    __tablename__ = 'products'
    id = db.Column(db.Integer, primary_key=True)
    seller_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    name = db.Column(db.String(255), nullable=False)
    description = db.Column(db.Text, nullable=False)
    price = db.Column(db.Numeric(10, 2), nullable=False)
    currency = db.Column(db.String(3), nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())

class Order(db.Model):
    __tablename__ = 'orders'
    id = db.Column(db.Integer, primary_key=True)
    buyer_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('products.id'), nullable=False)
    quantity = db.Column(db.Integer, nullable=False)
    total_price = db.Column(db.Numeric(10, 2), nullable=False)
    status = db.Column(db.String(50), nullable=False)
    created_at = db.Column(db.TIMESTAMP, server_default=db.func.current_timestamp())

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

    try:
        if User.query.filter_by(email=data['email']).first():
            app.logger.error('Email already registered')
            return jsonify({'message': 'Email already registered'}), 409

        hashed_password = generate_password_hash(data['password'], method='sha256')
        new_user = User(username=data['username'], email=data['email'], password_hash=hashed_password)
        db.session.add(new_user)
        db.session.commit()
        app.logger.info('Registration successful for user %s', data['username'])
        return jsonify({'message': 'Registration successful'}), 201
    except Exception as e:
        app.logger.error('Registration error: %s', str(e))
        return jsonify({'message': 'Internal server error'}), 500

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data or not all(key in data for key in ['email', 'password']):
        app.logger.error('Missing data during login')
        return jsonify({'message': 'Missing data'}), 400

    try:
        user = User.query.filter_by(email=data['email']).first()
        if user and check_password_hash(user.password_hash, data['password']):
            login_user(user)
            app.logger.info('Login successful for user %s', user.username)
            return jsonify({'message': 'Login successful', 'username': user.username}), 200

        app.logger.error('Invalid email or password during login')
        return jsonify({'message': 'Invalid email or password'}), 401
    except Exception as e:
        app.logger.error('Login error: %s', str(e))
        return jsonify({'message': 'Internal server error'}), 500

@app.route('/debug-number', methods=['GET'])
@login_required
def debug_number():
    try:
        debug_num = random.randint(1, 100)
        app.logger.info('Generated debug number: %d', debug_num)
        return jsonify({'debugNumber': debug_num})
    except Exception as e:
        app.logger.error('Debug number generation error: %s', str(e))
        return jsonify({'message': 'Internal server error'}), 500

# Global error handler
@app.errorhandler(Exception)
def handle_exception(e):
    # Log the error before sending a response
    app.logger.error('Unhandled Exception: %s', str(e))

    if isinstance(e, HTTPException):
        return jsonify(error=str(e)), e.code

    return jsonify(error='Internal Server Error'), 500

if __name__ == '__main__':
    db.create_all()
    app.run(host='0.0.0.0', port=8000, debug=True)
