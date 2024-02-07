import os
from flask import Flask, jsonify
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)

# Определение конфигурации базы данных в зависимости от среды
ENV = os.getenv('FLASK_ENV', 'development')
if ENV == 'production':
    app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'postgresql://user:pass@localhost/prod_db')
else:
    app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'

db = SQLAlchemy(app)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)

@app.route('/users', methods=['GET'])
def get_users():
    users = User.query.all()
    return jsonify([{'id': user.id, 'username': user.username} for user in users])

if __name__ == '__main__':
    db.create_all()
    app.run(debug=True)
