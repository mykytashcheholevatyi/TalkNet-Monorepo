import React from 'react';
import { BrowserRouter as Router, Route, Switch, Link } from 'react-router-dom';
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

        <Switch>
          <Route exact path="/" component={HomePage} />
          <Route path="/create-post" component={PostCreationPage} />
          <Route path="/create-community" component={CommunityCreationPage} />
          <Route path="/community/:id" component={CommunityPage} />
          <Route path="/login" component={LoginPage} />
          <Route path="/post/:id" component={PostPage} />
          <Route path="/profile/:id" component={ProfilePage} />
          <Route path="/register" component={RegisterPage} />
          <Route path="/search" component={SearchResultsPage} />
          <Route path="/settings" component={SettingsPage} />
          {/* Дополнительные маршруты могут быть добавлены здесь */}
        </Switch>
      </div>
    </Router>
  );
}

export default App;
