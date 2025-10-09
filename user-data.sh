#!/bin/bash
set -e

# Log everything to a file for debugging
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script..."

# Update system
yum update -y

# Install Node.js 18
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
yum install -y nodejs

# Install git
yum install -y git

# Create app directory
mkdir -p /opt/webapp
cd /opt/webapp

# Create the Node.js application
cat > server.js <<'EOFSERVER'
const http = require('http');
const { S3Client, GetObjectCommand } = require('@aws-sdk/client-s3');

const BUCKET_NAME = '${bucket_name}';
const AWS_REGION = '${aws_region}';
const PORT = 80;

// Initialize S3 client
const s3Client = new S3Client({ region: AWS_REGION });

// Helper function to get content from S3
async function getS3Content(key) {
  try {
    const command = new GetObjectCommand({
      Bucket: BUCKET_NAME,
      Key: key
    });
    const response = await s3Client.send(command);
    const content = await response.Body.transformToString();
    return content;
  } catch (error) {
    console.error('Error fetching ' + key + ':', error);
    return null;
  }
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
  console.log(new Date().toISOString() + ' - ' + req.method + ' ' + req.url);

  if (req.url === '/' || req.url === '/index.html') {
    try {
      // Fetch content from S3
      const message = await getS3Content('message.txt');
      const configStr = await getS3Content('config.json');
      const config = configStr ? JSON.parse(configStr) : null;

      // Build features list
      let featuresList = '';
      if (config && config.features) {
        config.features.forEach(function(f) {
          featuresList += '<li>' + f + '</li>';
        });
      }

      // Build config section
      let configSection = '';
      if (config) {
        configSection = '<div class="section">' +
          '<h2>⚙️ Application Configuration</h2>' +
          '<div class="info-grid">' +
            '<div class="info-item">' +
              '<strong>App Name</strong>' +
              config.app_name +
            '</div>' +
            '<div class="info-item">' +
              '<strong>Version</strong>' +
              config.version +
            '</div>' +
          '</div>' +
          '<p style="margin-top: 15px;">' + config.description + '</p>' +
          '<h3 style="margin-top: 20px; color: #333;">Features:</h3>' +
          '<ul class="features">' +
            featuresList +
          '</ul>' +
        '</div>';
      }

      // Generate HTML response
      const html = '<!DOCTYPE html>' +
'<html lang="en">' +
'<head>' +
'    <meta charset="UTF-8">' +
'    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
'    <title>Hello World - EC2 + S3</title>' +
'    <style>' +
'        * {' +
'            margin: 0;' +
'            padding: 0;' +
'            box-sizing: border-box;' +
'        }' +
'        body {' +
'            font-family: \'Segoe UI\', Tahoma, Geneva, Verdana, sans-serif;' +
'            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);' +
'            min-height: 100vh;' +
'            display: flex;' +
'            justify-content: center;' +
'            align-items: center;' +
'            padding: 20px;' +
'        }' +
'        .container {' +
'            background: white;' +
'            border-radius: 20px;' +
'            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);' +
'            max-width: 800px;' +
'            width: 100%;' +
'            padding: 40px;' +
'            animation: fadeIn 1s ease-in;' +
'        }' +
'        @keyframes fadeIn {' +
'            from { opacity: 0; transform: translateY(-20px); }' +
'            to { opacity: 1; transform: translateY(0); }' +
'        }' +
'        h1 {' +
'            color: #667eea;' +
'            font-size: 2.5em;' +
'            margin-bottom: 20px;' +
'            text-align: center;' +
'        }' +
'        .badge {' +
'            display: inline-block;' +
'            background: #667eea;' +
'            color: white;' +
'            padding: 5px 15px;' +
'            border-radius: 20px;' +
'            font-size: 0.8em;' +
'            margin: 5px;' +
'        }' +
'        .section {' +
'            margin: 30px 0;' +
'            padding: 20px;' +
'            background: #f8f9fa;' +
'            border-radius: 10px;' +
'            border-left: 4px solid #667eea;' +
'        }' +
'        .section h2 {' +
'            color: #333;' +
'            font-size: 1.5em;' +
'            margin-bottom: 15px;' +
'        }' +
'        .section p {' +
'            color: #666;' +
'            line-height: 1.6;' +
'            font-size: 1.1em;' +
'        }' +
'        .info-grid {' +
'            display: grid;' +
'            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));' +
'            gap: 15px;' +
'            margin-top: 15px;' +
'        }' +
'        .info-item {' +
'            background: white;' +
'            padding: 15px;' +
'            border-radius: 8px;' +
'            border: 1px solid #e0e0e0;' +
'        }' +
'        .info-item strong {' +
'            color: #667eea;' +
'            display: block;' +
'            margin-bottom: 5px;' +
'        }' +
'        .features {' +
'            list-style: none;' +
'            padding: 0;' +
'        }' +
'        .features li {' +
'            padding: 10px;' +
'            margin: 5px 0;' +
'            background: white;' +
'            border-radius: 5px;' +
'            border-left: 3px solid #764ba2;' +
'        }' +
'        .features li:before {' +
'            content: "✓ ";' +
'            color: #667eea;' +
'            font-weight: bold;' +
'            margin-right: 10px;' +
'        }' +
'        .footer {' +
'            text-align: center;' +
'            margin-top: 30px;' +
'            color: #999;' +
'            font-size: 0.9em;' +
'        }' +
'        .status {' +
'            text-align: center;' +
'            padding: 15px;' +
'            background: #d4edda;' +
'            border: 1px solid #c3e6cb;' +
'            border-radius: 10px;' +
'            color: #155724;' +
'            margin-bottom: 20px;' +
'        }' +
'    </style>' +
'</head>' +
'<body>' +
'    <div class="container">' +
'        <div class="status">' +
'            <strong>✓ Connected Successfully!</strong> This page is served from an EC2 instance and displays content from S3.' +
'        </div>' +
'        ' +
'        <h1>🌍 Hello World!</h1>' +
'        <div style="text-align: center; margin-bottom: 30px;">' +
'            <span class="badge">EC2 Instance</span>' +
'            <span class="badge">S3 Storage</span>' +
'            <span class="badge">IAM Roles</span>' +
'        </div>' +
'' +
'        <div class="section">' +
'            <h2>📦 Content from S3 Bucket</h2>' +
'            <p>' + (message || 'Could not retrieve message from S3') + '</p>' +
'        </div>' +
'' +
        configSection +
'' +
'        <div class="section">' +
'            <h2>🏗️ Infrastructure Details</h2>' +
'            <div class="info-grid">' +
'                <div class="info-item">' +
'                    <strong>S3 Bucket</strong>' +
'                    ' + BUCKET_NAME +
'                </div>' +
'                <div class="info-item">' +
'                    <strong>AWS Region</strong>' +
'                    ' + AWS_REGION +
'                </div>' +
'                <div class="info-item">' +
'                    <strong>Web Server</strong>' +
'                    Node.js on EC2' +
'                </div>' +
'                <div class="info-item">' +
'                    <strong>Authentication</strong>' +
'                    IAM Instance Profile' +
'                </div>' +
'            </div>' +
'        </div>' +
'' +
'        <div class="footer">' +
'            <p>Deployed with Terraform | Powered by AWS</p>' +
'            <p style="margin-top: 5px;">Server Time: ' + new Date().toISOString() + '</p>' +
'        </div>' +
'    </div>' +
'</body>' +
'</html>';

      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(html);
    } catch (error) {
      console.error('Error:', error);
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Internal Server Error');
    }
  } else if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', timestamp: new Date().toISOString() }));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT, () => {
  console.log('Server running on port ' + PORT);
  console.log('Fetching content from S3 bucket: ' + BUCKET_NAME);
});
EOFSERVER

# Create package.json
cat > package.json <<'EOFPACKAGE'
{
  "name": "ec2-s3-webapp",
  "version": "1.0.0",
  "description": "Web application on EC2 that retrieves content from S3",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "@aws-sdk/client-s3": "^3.400.0"
  }
}
EOFPACKAGE

# Install dependencies
npm install

# Create systemd service
cat > /etc/systemd/system/webapp.service <<EOFSERVICE
[Unit]
Description=EC2 S3 Web Application
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Start and enable service
systemctl daemon-reload
systemctl enable webapp
systemctl start webapp

echo "User data script completed successfully!"
echo "Web application should be available on port 80"