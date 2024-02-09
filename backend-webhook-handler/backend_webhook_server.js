const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const app = express();
const port = 9001; // Убедитесь, что этот порт свободен на вашем сервере

app.use(express.json()); // Поддержка JSON-кодированных тел запросов

const secret = 'your_webhook_secret'; // Используйте ваш фактический секрет веб-хука здесь

app.post('/backend-webhook', (req, res) => {
    const signature = req.headers['x-hub-signature-256'] || '';
    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(JSON.stringify(req.body));
    const digest = 'sha256=' + hmac.digest('hex');

    if (signature !== digest) {
        console.error('Несовпадение подписей');
        return res.status(401).send('Несовпадение подписей');
    }

    // Проверка обновлений в главной ветке
    const branch = req.body.ref;
    if (branch === 'refs/heads/main') {
        exec('bash /srv/talknet/backend/scripts/update_and_restart.sh', (err, stdout, stderr) => {
            if (err) {
                console.error(`Ошибка exec: ${err}`);
                return res.status(500).send('Ошибка сервера');
            }
            console.log(`stdout: ${stdout}`);
            if (stderr) console.error(`stderr: ${stderr}`);
            res.status(200).send('Бэкенд успешно обновлен и перезапущен');
        });
    } else {
        console.log('Пуш был не в главную ветку, действий не предпринимается');
        res.status(200).send('Пуш был не в главную ветку, действий не предпринимается');
    }
});

app.listen(port, () => {
    console.log(`Обработчик веб-хука бэкенда запущен на порту ${port}`);
});
