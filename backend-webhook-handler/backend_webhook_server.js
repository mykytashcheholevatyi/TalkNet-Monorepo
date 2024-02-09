const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const app = express();
const port = 9001; // Ensure this port is free on your server

app.use(express.json()); // Support for JSON-encoded bodies

const secret = 'your_webhook_secret'; // Use your actual webhook secret here

app.post('/backend-webhook', (req, res) => {
    const signature = req.headers['x-hub-signature-256'] || '';
    const hmac = crypto.createHmac('sha256', secret);
    const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');

    if (signature !== digest) {
        console.error('Mismatched signatures');
        return res.status(401).send('Mismatched signatures');
    }

    // Check for updates to the main branch
    const branch = req.body.ref;
    if(branch === 'refs/heads/main'){
        exec('bash /srv/talknet/backend/scripts/update_and_restart.sh', (err, stdout, stderr) => {
            if (err) {
                console.error(`exec error: ${err}`);
                return res.status(500).send('Server error');
            }
            console.log(`stdout: ${stdout}`);
            if (stderr) console.error(`stderr: ${stderr}`);
            res.status(200).send('Backend successfully updated and restarted');
        });
    } else {
        console.log('Push was not to main branch, no action taken');
        res.status(200).send('Push was not to main branch, no action taken');
    }
});

app.listen(port, () => {
    console.log(`Backend webhook handler running on port ${port}`);
});
