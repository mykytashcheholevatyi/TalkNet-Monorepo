import React from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import './App.css';

// Импорт компонентов страниц
import WelcomePage from './pages/WelcomePage';
import HomePageUA from './pages/HomePageUA';
import HomePageRU from './pages/HomePageRU';
import HomePageEN from './pages/HomePageEN';
import CommunityCreationPage from './pages/CommunityCreationPage';
import CommunityPage from './pages/CommunityPage';
import LoginPage from './pages/LoginPage';
import PostCreationPage from './pages/PostCreationPage';
import PostPage from './pages/PostPage';
import ProfilePage from './pages/ProfilePage';
import RegisterPage from './pages/RegisterPage';
import SearchResultsPage from './pages/SearchResultsPage';
import SettingsPage from './pages/SettingsPage';
// Импорт других компонентов страниц...

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <nav className="App-nav">
            <Link to="/" className="App-link">Welcome</Link>
            <Link to="/en" className="App-link">EN</Link>
            <Link to="/ru" className="App-link">RU</Link>
            <Link to="/ua" className="App-link">UA</Link>
            {/* Добавьте ссылки на другие языки */}
          </nav>
          <div className="login-register">
            <Link to="/login" className="App-link">Login</Link>
            <Link to="/register" className="App-link">Register</Link>
          </div>
        </header>

        <main className="App-main">
          <Routes>
            <Route path="/" element={<WelcomePage />} />
            <Route path="/en" element={<HomePageEN />} />
            <Route path="/ru" element={<HomePageRU />} />
            <Route path="/ua" element={<HomePageUA />} />
            {/* Добавьте маршруты для других языковых версий и страниц */}
            <Route path="/community/create" element={<CommunityCreationPage />} />
            <Route path="/community/:id" element={<CommunityPage />} />
            <Route path="/login" element={<LoginPage />} />
            <Route path="/post/create" element={<PostCreationPage />} />
            <Route path="/post/:id" element={<PostPage />} />
            <Route path="/profile/:id" element={<ProfilePage />} />
            <Route path="/register" element={<RegisterPage />} />
            <Route path="/search" element={<SearchResultsPage />} />
            <Route path="/settings" element={<SettingsPage />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
