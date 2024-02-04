import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import logo from './logo.svg';
import './App.css';

// Импорт страниц
import HomePage from './pages/HomePage';
import CommunityCreationPage from './pages/CommunityCreationPage';
import CommunityPage from './pages/CommunityPage';
import LoginPage from './pages/LoginPage';
import PostCreationPage from './pages/PostCreationPage';
import PostPage from './pages/PostPage';
import ProfilePage from './pages/ProfilePage';
import RegisterPage from './pages/RegisterPage';
import SearchResultsPage from './pages/SearchResultsPage';
import SettingsPage from './pages/SettingsPage';

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <img src={logo} className="App-logo" alt="logo" />
          <nav>
            <Link to="/" className="App-link">Home</Link>
            <Link to="/create-post" className="App-link">Create Post</Link>
            <Link to="/create-community" className="App-link">Create Community</Link>
            <Link to="/login" className="App-link">Login</Link>
            {/* Добавьте оставшиеся ссылки аналогичным образом */}
          </nav>
        </header>

        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/create-post" element={<PostCreationPage />} />
          <Route path="/create-community" element={<CommunityCreationPage />} />
          {/* Определите маршруты для оставшихся страниц аналогичным образом */}
        </Routes>
      </div>
    </Router>
  );
}

export default App;
