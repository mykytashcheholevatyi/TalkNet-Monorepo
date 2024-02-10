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
      const response = await fetch('http://85.215.65.78:8000/register', {
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
        {/* Form fields */}
        <button type="submit">Register</button>
      </form>
      {errors.form && <div>{errors.form}</div>}
    </div>
  );
}

export default RegisterPage;
