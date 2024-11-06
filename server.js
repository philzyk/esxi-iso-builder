const express = require('express');
const multer = require('multer');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const app = express();
const port = 3000;

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, process.env.UPLOAD_DIR || 'uploads')
    },
    filename: (req, file, cb) => {
        cb(null, Date.now() + '-' + file.originalname)
    }
});

const upload = multer({ storage: storage });

app.use(express.json());

// Handle ESXi customization request
app.post('/api/customize', upload.single('inputBundle'), (req, res) => {
    const { 
        version,
        updateMode,
        vftEnabled,
        outputFormat,
        customImageName,
        loadVibs,
        removeVibs
    } = req.body;

    const inputBundle = req.file ? req.file.path : '';
    const outputDir = process.env.OUTPUT_DIR || 'output';

    // Construct PowerShell command
    const args = [
        '-File', '/scripts/run-script.ps1',
        '-iZip', inputBundle,
        '-outDir', outputDir
    ];

    if (version) args.push(`-${version}`);
    if (updateMode === 'true') args.push('-update');
    if (vftEnabled === 'true') args.push('-vft');
    if (outputFormat === 'zip') args.push('-ozip');
    if (customImageName) args.push('-ipname', customImageName);
    if (loadVibs) args.push('-load', loadVibs);
    if (removeVibs) args.push('-remove', removeVibs);

    // Execute PowerShell script
    const powershell = spawn('pwsh', args);

    let output = '';
    let error = '';

    powershell.stdout.on('data', (data) => {
        output += data.toString();
    });

    powershell.stderr.on('data', (data) => {
        error += data.toString();
    });

    powershell.on('close', (code) => {
        if (code !== 0) {
            return res.status(500).json({
                success: false,
                error: error || 'Process failed'
            });
        }

        res.json({
            success: true,
            output,
            outputFile: path.join(outputDir, customImageName || 'ESXi-customized')
        });
    });
});

// Get build status
app.get('/api/status/:id', (req, res) => {
    // Implementation for checking build status
    res.json({ status: 'in_progress' });
});

app.listen(3000, '0.0.0.0', () => {
  console.log('App running on 0.0.0.0:3000');
});
