import React from 'react';

function HomePageRU() {
  // Эмуляция списка постов
  const posts = [
    {
      id: 1,
      title: 'Заголовок поста 1',
      content: 'Содержание поста 1...',
      author: 'Пользователь 1',
      createdAt: 'Сегодня, 10:00',
    },
    {
      id: 2,
      title: 'Заголовок поста 2',
      content: 'Содержание поста 2...',
      author: 'Пользователь 2',
      createdAt: 'Вчера, 15:30',
    },
    // Добавьте больше постов
  ];

  return (
    <div className="homepage-ru">
      <h1>Главная страница форума (RU)</h1>
      <div className="post-list">
        {posts.map((post) => (
          <div key={post.id} className="post">
            <h2>{post.title}</h2>
            <p>{post.content}</p>
            <p>Автор: {post.author}</p>
            <p>Дата: {post.createdAt}</p>
          </div>
        ))}
      </div>
    </div>
  );
}

export default HomePageRU;
