const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const app = express();
const port = 9001; // Убедитесь, что этот порт свободен и открыт на вашем сервере

app.use(express.json()); // Поддержка JSON-encoded bodies

const secret = 'your_webhook_secret'; // Замените на ваш секрет, используемый в настройках веб-хука GitHub

app.post('/backend-webhook', (req, res) => {
    const signature = req.headers['x-hub-signature'];

    // Создаем HMAC с SHA1 хешем, используя секрет как ключ и тело запроса как сообщение
    const hash = `sha1=${crypto.createHmac('sha1', secret)
                       .update(JSON.stringify(req.body))
                       .digest('hex')}`;

    // Проверяем, совпадает ли подпись
    if (signature !== hash) {
        console.error('Mismatched signatures');
        return res.status(401).send('Mismatched signatures');
    }

    // Путь к скрипту обновления бэкенда
    const scriptPath = '/srv/talknet/backend/scripts/full_deploy_backend.sh';
    
    exec(`bash ${scriptPath}`, (err, stdout, stderr) => {
        if (err) {
            console.error(`exec error: ${err}`);
            return res.status(500).send('Server error');
        }
        console.log(`stdout: ${stdout}`);
        console.log(`stderr: ${stderr}`);
        res.status(200).send('OK');
    });
});

app.listen(port, () => {
    console.log(`Backend webhook handler running on port ${port}`);
});
