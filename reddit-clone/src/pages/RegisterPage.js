import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';

function RegisterPage() {
  const [formData, setFormData] = useState({ username: '', email: '', password: '', confirmPassword: '' });
  const [errors, setErrors] = useState({});
  const navigate = useNavigate();

  const validateField = (name, value) => {
    switch (name) {
      case 'username':
        return !value.trim() ? 'Username is required' : '';
      case 'email':
        return !/\S+@\S+\.\S+/.test(value) ? 'Email is invalid' : '';
      case 'password':
        return value.length < 6 ? 'Password must be at least 6 characters' : '';
      case 'confirmPassword':
        return value !== formData.password ? 'Passwords do not match' : '';
      default:
        return '';
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    const error = validateField(name, value);
    setErrors(prev => ({ ...prev, [name]: error }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    const formErrors = Object.keys(formData).reduce((acc, key) => {
      const error = validateField(key, formData[key]);
      if (error) acc[key] = error;
      return acc;
    }, {});

    setErrors(formErrors);
    if (Object.values(formErrors).some(error => error)) return;

    try {
      const response = await fetch('http://localhost:5000/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });

      if (!response.ok) {
        const data = await response.json();
        setErrors({ form: data.message });
        return;
      }
      navigate('/login');
    } catch (error) {
      setErrors({ form: 'An unexpected error occurred, please try again.' });
    }
  };

  return (
    <div className="register-page">
      <h1>Register</h1>
      <form onSubmit={handleSubmit} noValidate>
        <div>
          <label>Username</label>
          <input type="text" name="username" value={formData.username} onChange={handleInputChange} />
          {errors.username && <div>{errors.username}</div>}
        </div>
        <div>
          <label>Email</label>
          <input type="email" name="email" value={formData.email} onChange={handleInputChange} />
          {errors.email && <div>{errors.email}</div>}
        </div>
        <div>
          <label>Password</label>
          <input type="password" name="password" value={formData.password} onChange={handleInputChange} />
          {errors.password && <div>{errors.password}</div>}
        </div>
        <div>
          <label>Confirm Password</label>
          <input type="password" name="confirmPassword" value={formData.confirmPassword} onChange={handleInputChange} />
          {errors.confirmPassword && <div>{errors.confirmPassword}</div>}
        </div>
        <button type="submit">Register</button>
      </form>
      {errors.form && <div>{errors.form}</div>}
    </div>
  );
}

export default RegisterPage;
