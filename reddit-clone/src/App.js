import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import logo from './logo.svg'; // Путь к лого
import './App.css'; // Подключение стилей

// Импорт страниц
import HomePage from './pages/HomePage';
// Другие импорты...

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <p>
            Edit <code>src/App.js</code> and save to reload.
          </p>
          <nav>
            <Link to="/" className="App-link">Home</Link>
            {/* Добавьте другие ссылки для навигации */}
          </nav>
          <a
            className="App-link"
            href="https://reactjs.org"
            target="_blank"
            rel="noopener noreferrer"
          >
            Learn React
          </a>
        </header>

        <Routes>
          <Route path="/" element={<HomePage />} />
          {/* Определите другие маршруты здесь */}
        </Routes>
      </div>
    </Router>
  );
}

export default App;
