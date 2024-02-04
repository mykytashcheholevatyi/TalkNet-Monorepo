import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import logo from './logo.svg';
import './App.css';

// Импорт страниц
import HomePage from './pages/HomePage';
import PostCreationPage from './pages/PostCreationPage';
import CommunityCreationPage from './pages/CommunityCreationPage';
import CommunityPage from './pages/CommunityPage';
import LoginPage from './pages/LoginPage';
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
          <p>Edit <code>src/App.js</code> and save to reload.</p>
          <Link to="/" className="App-link">Home</Link>
          {/* Добавьте ссылки на другие страницы здесь */}
          <a className="App-link" href="https://reactjs.org" target="_blank" rel="noopener noreferrer">Learn React</a>
        </header>

        <Routes>
          <Route exact path="/" element={<HomePage />} />
          <Route path="/create-post" element={<PostCreationPage />} />
          <Route path="/create-community" element={<CommunityCreationPage />} />
          <Route path="/community/:id" element={<CommunityPage />} />
          <Route path="/login" element={<LoginPage />} />
          <Route path="/post/:id" element={<PostPage />} />
          <Route path="/profile/:id" element={<ProfilePage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/search" element={<SearchResultsPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          {/* Дополнительные маршруты могут быть добавлены здесь */}
        </Routes>
      </div>
    </Router>
  );
}

export default App;
