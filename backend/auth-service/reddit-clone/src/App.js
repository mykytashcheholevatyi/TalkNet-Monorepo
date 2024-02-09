import React, { Suspense, lazy } from 'react';
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom';
import './App.css';
import ErrorBoundary from './components/ErrorBoundary'; // Error boundary component
import NavBar from './components/NavBar'; // Navigation bar component

// Lazy loading components
const WelcomePage = lazy(() => import('./pages/WelcomePage'));
const HomePageUA = lazy(() => import('./pages/HomePageUA'));
const HomePageRU = lazy(() => import('./pages/HomePageRU'));
const HomePageEN = lazy(() => import('./pages/HomePageEN'));
const CommunityCreationPage = lazy(() => import('./pages/CommunityCreationPage'));
const CommunityPage = lazy(() => import('./pages/CommunityPage'));
const LoginPage = lazy(() => import('./pages/LoginPage'));
const PostCreationPage = lazy(() => import('./pages/PostCreationPage'));
const PostPage = lazy(() => import('./pages/PostPage'));
const ProfilePage = lazy(() => import('./pages/ProfilePage'));
const RegisterPage = lazy(() => import('./pages/RegisterPage'));
const SearchResultsPage = lazy(() => import('./pages/SearchResultsPage'));
const SettingsPage = lazy(() => import('./pages/SettingsPage'));
// Lazy load other page components...

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          <NavBar />
        </header>

        <main className="App-main">
          <ErrorBoundary>
            <Suspense fallback={<div>Loading...</div>}>
              <Routes>
                <Route path="/" element={<WelcomePage />} />
                <Route path="/en" element={<HomePageEN />} />
                <Route path="/ru" element={<HomePageRU />} />
                <Route path="/ua" element={<HomePageUA />} />
                {/* Other routes */}
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
            </Suspense>
          </ErrorBoundary>
        </main>
      </div>
    </Router>
  );
}

export default App;
