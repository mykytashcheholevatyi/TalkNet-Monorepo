const express = require('express');
const { exec } = require('child_process');
const crypto = require('crypto');
const app = express();
const port = 9001; // Make sure this port is available on your server

app.use(express.json()); // Support for JSON-encoded request bodies

const secret = 'your_webhook_secret'; // Use your actual webhook secret here

app.post('/backend-webhook', (req, res) => {
    const signature = req.headers['x-hub-signature-256'] || '';
    const hmac = crypto.createHmac('sha256', secret);
    hmac.update(JSON.stringify(req.body));
    const digest = 'sha256=' + hmac.digest('hex');

    if (signature !== digest) {
        console.error('Signatures mismatch');
        return res.status(401).send('Signatures mismatch');
    }

    // Check for updates in the main branch
    const branch = req.body.ref;
    if (branch === 'refs/heads/main') {
        // Check if commit message contains [LOGS_UPDATE] tag
        const commitMessage = req.body.head_commit.message;
        if (commitMessage.includes('[LOGS_UPDATE]')) {
            console.log('Commit contains logs update tag, skipping action');
            return res.status(200).send('Commit contains logs update tag, skipping action');
        }

        exec('bash /srv/talknet/backend/scripts/update_and_restart.sh', (err, stdout, stderr) => {
            if (err) {
                console.error(`exec error: ${err}`);
                return res.status(500).send('Internal server error');
            }
            console.log(`stdout: ${stdout}`);
            if (stderr) console.error(`stderr: ${stderr}`);
            res.status(200).send('Backend updated and restarted successfully');
        });
    } else {
        console.log('Push was not to the main branch, no action taken');
        res.status(200).send('Push was not to the main branch, no action taken');
    }
});

app.listen(port, () => {
    console.log(`Backend webhook handler running on port ${port}`);
});
