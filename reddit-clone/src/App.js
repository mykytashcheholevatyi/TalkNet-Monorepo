import React from 'react';
import { BrowserRouter as Router, Route, Routes, Link } from 'react-router-dom';
import './App.css';

// Импорт страниц для разных языков
import HomePageUA from './pages/HomePageUA';
import HomePageRU from './pages/HomePageRU';
import HomePageEN from './pages/HomePageEN';
// Импорт других страниц...

function App() {
  return (
    <Router>
      <div className="App">
        <header className="App-header">
          {/* Ссылки для переключения языков */}
          <Link to="/ua" className="App-link">UA</Link>
          <Link to="/ru" className="App-link">RU</Link>
          <Link to="/en" className="App-link">EN</Link>
          {/* Добавьте оставшиеся ссылки аналогичным образом */}
        </header>

        <Routes>
          <Route path="/ua" element={<HomePageUA />} />
          <Route path="/ru" element={<HomePageRU />} />
          <Route path="/en" element={<HomePageEN />} />
          {/* Определите маршруты для оставшихся страниц аналогичным образом */}
        </Routes>
      </div>
    </Router>
  );
}

export default App;
