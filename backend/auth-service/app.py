from flask import Flask, jsonify, render_template_string
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate  # Импорт Flask-Migrate

app = Flask(__name__)

# Конфигурация базы данных
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///site.db'
db = SQLAlchemy(app)
migrate = Migrate(app, db)  # Инициализация Flask-Migrate

# Модель пользователя
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(20), unique=True, nullable=False)

# HTML шаблон для отображения пользователей
html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>Users List</title>
</head>
<body>
    <h2>Registered Users</h2>
    <ul>
    {% for user in users %}
        <li>{{ user.username }}</li>
    {% else %}
        <li>No users found.</li>
    {% endfor %}
    </ul>
</body>
</html>
"""

# Маршрут для отображения пользователей
@app.route('/users', methods=['GET'])
def get_users():
    users = User.query.all()
    return render_template_string(html_template, users=users)

# Главная страница
@app.route('/')
def index():
    return '<h1>Welcome to the Flask App!</h1><p>Go to <a href="/users">/users</a> to see the list of users.</p>'

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
