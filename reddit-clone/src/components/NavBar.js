import React from 'react';
import { Link } from 'react-router-dom';

const NavBar = () => {
  return (
    <nav className="App-nav">
      <Link to="/" className="App-link">Welcome</Link>
      <Link to="/en" className="App-link">EN</Link>
      <Link to="/ru" className="App-link">RU</Link>
      <Link to="/ua" className="App-link">UA</Link>
      <Link to="/login" className="App-link">Login</Link>
      <Link to="/register" className="App-link">Register</Link>
      {/* Add more links as needed */}
    </nav>
  );
};

export default NavBar;
