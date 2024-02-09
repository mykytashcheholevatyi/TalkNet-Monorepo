const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const app = express();
const port = 9000; // Изменим порт на 9000

app.use(bodyParser.json());

app.post('/webhook', (req, res) => {
  // Здесь можно добавить проверку секрета из webhook для безопасности
  exec('/var/www/TalkNet-Monorepo/reddit-clone/update_and_restart.sh', (err, stdout, stderr) => {
    if (err) {
      console.error(err);
      return res.status(500).send('Server error');
    }
    console.log(stdout);
    res.status(200).send('OK');
  });
});

app.listen(port, () => {
  console.log(`Webhook handler running on port ${port}`);
});
