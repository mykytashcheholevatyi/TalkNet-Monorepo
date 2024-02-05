import React, { useState } from 'react';

function LoginPage() {
  // Состояние для хранения данных формы
  const [formData, setFormData] = useState({
    email: '',
    password: '',
  });

  // Обработчик изменения полей формы
  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData({
      ...formData,
      [name]: value,
    });
  };

  // Обработчик отправки формы
  const handleSubmit = (e) => {
    e.preventDefault();
    // Отправка данных на сервер для аутентификации
    // Вместо этого места, вы должны добавить код для отправки данных на сервер
    console.log('Отправка данных:', formData);
  };

  return (
    <div>
      <h1>Login</h1>
      <p>Please log in to access the forum.</p>
      <form onSubmit={handleSubmit}>
        <div>
          <label>Email:</label>
          <input
            type="email"
            name="email"
            value={formData.email}
            onChange={handleInputChange}
            required
          />
        </div>
        <div>
          <label>Password:</label>
          <input
            type="password"
            name="password"
            value={formData.password}
            onChange={handleInputChange}
            required
          />
        </div>
        <button type="submit">Login</button>
      </form>
    </div>
  );
}

export default LoginPage;
