from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required
from werkzeug.security import generate_password_hash, check_password_hash
import random
import os

app = Flask(__name__)
CORS(app)
app.config['SECRET_KEY'] = os.urandom(24)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager(app)

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)
    email = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(80), nullable=False)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    username = data.get('username')
    password = data.get('password')

    if not all([email, username, password]):
        return jsonify({'message': 'Missing data'}), 400

    existing_user = User.query.filter_by(email=email).first()
    if existing_user:
        return jsonify({'message': 'Email already registered'}), 409

    hashed_password = generate_password_hash(password, method='sha256')
    new_user = User(username=username, email=email, password=hashed_password)
    db.session.add(new_user)
    db.session.commit()

    return jsonify({'message': 'Registration successful'}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    if not data:
        return jsonify({'message': 'No data provided'}), 400

    email = data.get('email')
    password = data.get('password')
    user = User.query.filter_by(email=email).first()

    if user and check_password_hash(user.password, password):
        login_user(user)
        return jsonify({'message': 'Login successful', 'username': user.username}), 200

    return jsonify({'message': 'Invalid email or password'}), 401

@app.route('/debug-number', methods=['GET'])
@login_required
def debug_number():
    return jsonify({'debugNumber': random.randint(1, 100)})

if __name__ == '__main__':
    db.create_all()
    app.run(debug=True)
