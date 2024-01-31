function handleLanguageChange(langPath) {
    window.location.href = langPath;
}


function searchTopics() {
    const searchQuery = document.getElementById('searchBox').value.trim();
    // Здесь можно добавить логику для выполнения поиска на фронтенде или отправки запроса к API
    alert("Search for: " + searchQuery);
    // Предположим, что функция updateForumThreads обновляет отображаемые темы в соответствии с поисковым запросом
    updateForumThreads(searchQuery);
}

function openThread(threadId) {
    // Перенаправление пользователя на страницу выбранной темы
    window.location.href = `thread.html?id=${threadId}`;
}

// Заглушка для функции, которая обновляет список тем на форуме
function updateForumThreads(searchQuery) {
    console.log("Update forum threads based on the search query: " + searchQuery);
    // Здесь будет ваша логика для обновления списка тем на странице
}

function postReply() {
    const message = document.getElementById('replyMessage').value.trim();
    if (!message) {
        alert("Please write a message before posting.");
        return;
    }
    // Здесь можно добавить логику для отправки сообщения на сервер
    console.log("Posting reply:", message);
    // Очистка поля ввода после отправки
    document.getElementById('replyMessage').value = '';
    // Предположим, что функция addReplyToThread добавляет ответ в текущую тему на странице
    addReplyToThread(message);
}

// Заглушка для функции, которая добавляет ответ в текущую тему
function addReplyToThread(message) {
    console.log("Add reply to the thread: " + message);
    // Здесь будет ваша логика для добавления ответа в DOM
}
