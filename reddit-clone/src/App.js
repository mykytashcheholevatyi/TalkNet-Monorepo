import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import './App.css';

// Импорт страниц
import CommunityCreationPage from './pages/CommunityCreationPage';
import CommunityPage from './pages/CommunityPage';
import HomePage from './pages/HomePage';
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
        <Routes>
          <Route path="/" element={<HomePage />} />
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
      </div>
    </Router>
  );
}

export default App;
