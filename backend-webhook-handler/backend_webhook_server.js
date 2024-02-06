const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const app = express();
const port = 9001; // Убедитесь, что этот порт свободен на вашем сервере

app.use(express.json()); // Поддержка JSON-encoded bodies

const secret = 'your_webhook_secret'; // Используйте ваш секретный код

app.post('/backend-webhook', (req, res) => {
    const signature = req.headers['x-hub-signature-256'] || '';
    const hmac = crypto.createHmac('sha256', secret);
    const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');

    if (signature !== digest) {
        return res.status(401).send('Mismatched signatures');
    }

    // Проверка на обновление ветки main
    const branch = req.body.ref;
    if(branch === 'refs/heads/main'){
        exec('bash /srv/talknet/backend/scripts/full_deploy_backend.sh', (err, stdout, stderr) => {
            if (err) {
                console.error(`exec error: ${err}`);
                return res.status(500).send('Server error');
            }
            console.log(`stdout: ${stdout}`);
            console.log(`stderr: ${stderr}`);
            res.status(200).send('Backend successfully updated and restarted');
        });
    } else {
        res.status(200).send('Push was not to main branch, no action taken');
    }
});

app.listen(port, () => {
    console.log(`Backend webhook handler running on port ${port}`);
});
