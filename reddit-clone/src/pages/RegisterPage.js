import React, { useState } from 'react';

function RegisterPage() {
  // Состояния для полей ввода и обработки ошибок
  const [formData, setFormData] = useState({
    username: '',
    email: '',
    password: '',
    confirmPassword: '',
  });
  const [errors, setErrors] = useState({});

  // Обработчик изменения полей ввода
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

    // Проверка наличия ошибок валидации (добавьте свою логику валидации)
    const validationErrors = {};

    if (!formData.username) {
      validationErrors.username = 'Введите имя пользователя';
    }
    if (!formData.email) {
      validationErrors.email = 'Введите адрес электронной почты';
    }
    if (!formData.password) {
      validationErrors.password = 'Введите пароль';
    }
    if (formData.password !== formData.confirmPassword) {
      validationErrors.confirmPassword = 'Пароли не совпадают';
    }

    // Если есть ошибки валидации, установите их в состояние
    if (Object.keys(validationErrors).length > 0) {
      setErrors(validationErrors);
    } else {
      // Отправка данных на сервер (добавьте свою логику отправки)
      console.log('Данные успешно отправлены:', formData);
      // Сброс состояния формы и ошибок
      setFormData({
        username: '',
        email: '',
        password: '',
        confirmPassword: '',
      });
      setErrors({});
    }
  };

  return (
    <div>
      <h1>Register</h1>
      <p>Create a new account to join the community.</p>
      <form onSubmit={handleSubmit}>
        <div>
          <label htmlFor="username">Username</label>
          <input
            type="text"
            id="username"
            name="username"
            value={formData.username}
            onChange={handleInputChange}
          />
          {errors.username && <p className="error">{errors.username}</p>}
        </div>
        <div>
          <label htmlFor="email">Email</label>
          <input
            type="email"
            id="email"
            name="email"
            value={formData.email}
            onChange={handleInputChange}
          />
          {errors.email && <p className="error">{errors.email}</p>}
        </div>
        <div>
          <label htmlFor="password">Password</label>
          <input
            type="password"
            id="password"
            name="password"
            value={formData.password}
            onChange={handleInputChange}
          />
          {errors.password && <p className="error">{errors.password}</p>}
        </div>
        <div>
          <label htmlFor="confirmPassword">Confirm Password</label>
          <input
            type="password"
            id="confirmPassword"
            name="confirmPassword"
            value={formData.confirmPassword}
            onChange={handleInputChange}
          />
          {errors.confirmPassword && <p className="error">{errors.confirmPassword}</p>}
        </div>
        <button type="submit">Register</button>
      </form>
    </div>
  );
}

export default RegisterPage;
