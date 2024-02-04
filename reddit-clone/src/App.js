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

        <main>
          <h1>Welcome to Forulink!</h1>
          <p>The community-driven forum where you can share your thoughts, ideas, and discussions.</p>

          <section className="welcome-section">
            <h2>Get Started</h2>
            <p>Join our community to start engaging in lively discussions, share your expertise, or just browse the latest topics.</p>
          </section>

          <section className="categories-section">
            <h2>Categories</h2>
            <ul className="categories-list">
              <li>Technology & Gadgets</li>
              <li>Health & Wellness</li>
              <li>Travel & Adventure</li>
              <li>Food & Cuisine</li>
              {/* Добавьте другие категории по вашему выбору */}
            </ul>
          </section>

          <section className="recent-discussions">
            <h2>Recent Discussions</h2>
            <div className="discussion">
              <h3>What's the best programming language for beginners?</h3>
              <p>Started by Alice123 - 2 hours ago</p>
            </div>
            <div className="discussion">
              <h3>Your favorite travel destinations?</h3>
              <p>Started by TravelBug - 1 day ago</p>
            </div>
            {/* Добавьте другие обсуждения по вашему выбору */}
          </section>
        </main>

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
