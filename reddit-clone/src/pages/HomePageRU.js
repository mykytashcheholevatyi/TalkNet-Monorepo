import React, { useState } from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';

// Импорт компонентов страниц
import WelcomePage from './WelcomePage';
import CommunityCreationPage from './CommunityCreationPage';
import CommunityPage from './CommunityPage';
import LoginPage from './LoginPage';
import PostCreationPage from './PostCreationPage';
import PostPage from './PostPage';
import ProfilePage from './ProfilePage';
import RegisterPage from './RegisterPage';
import SearchResultsPage from './SearchResultsPage';
import SettingsPage from './SettingsPage';
function Forum() {
  // Эмуляция списка сообщений на форуме
  const [messages, setMessages] = useState([
    {
      id: 1,
      author: 'User1',
      content: 'Привет, это первое сообщение!',
    },
    {
      id: 2,
      author: 'User2',
      content: 'Привет, User1! Как дела?',
    },
    // Добавьте больше сообщений
  ]);

  // Функция для добавления нового сообщения
  const addMessage = (author, content) => {
    const newMessage = {
      id: messages.length + 1,
      author,
      content,
    };
    setMessages([...messages, newMessage]);
  };

  // Функция для отображения списка сообщений
  const renderMessages = () => {
    return messages.map((message) => (
      <div key={message.id} className="message">
        <p>Автор: {message.author}</p>
        <p>{message.content}</p>
      </div>
    ));
  };

  return (
    <Router>
      <div className="forum">
        <h1>Форум</h1>
        <div className="message-list">
          {renderMessages()}
        </div>
        <div className="message-input">
          <h2>Добавить новое сообщение:</h2>
          <input type="text" placeholder="Имя автора" id="author" />
          <textarea placeholder="Текст сообщения" id="content" />
          <button onClick={() => {
            const author = document.getElementById('author').value;
            const content = document.getElementById('content').value;
            if (author && content) {
              addMessage(author, content);
              document.getElementById('author').value = '';
              document.getElementById('content').value = '';
            }
          }}>Отправить</button>
        </div>
      </div>
    </Router>
  );
}

export default Forum;
