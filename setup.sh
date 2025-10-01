#!/bin/bash

# Update and upgrade the system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y
sudo apt --fix-broken install -y


# Install Python 3 and pip
echo "Installing Python 3 and pip..."
sudo apt install -y python3 python3-pip
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
sudo update-alternatives --set python /usr/bin/python3
sudo apt install python3-eventlet python3-flask python3-flask-socketio

# Install Git
echo "Installing Git..."
sudo apt install -y git

# Install WiFi Hotspot Service
echo "Installing WiFi Hotspot Service..."
sudo apt install network-manager

# Install UFW and enable port 5000
echo "Installing UFW and enabling port 5000..."
sudo apt install -y ufw
sudo ufw allow 5000


# Navigate to the project directory
cd coopsoil || exit

# Set up the virtual environment and install dependencies
echo "Setting up virtual environment and installing dependencies..."
# python3 -m venv .venv
# source .venv/bin/activate
# pip3 install -r requirements.txt
# deactivate

# Install dependencies globally
echo "Installing project dependencies globally..."
sudo pip3 install -r requirements.txt --break-system-packages

# Create the .env file
echo "Creating the .env file..."
cat <<EOL | sudo tee .env
SECRET_KEY=$(openssl rand -base64 32)
DEBUG=False
LOGGER=True
PORT=5000
MODE=prod
RELOAD=False
EOL

# Create log folder and file for uWSGI
echo "Creating log folder and log file for uWSGI..."
sudo mkdir -p /var/log/uwsgi
sudo touch /var/log/uwsgi/coopsoil.log

# Create the uwsgi.ini file
echo "Creating uwsgi.ini configuration file..."
cat <<EOL | sudo tee uwsgi.ini
[uwsgi]
chdir = $(pwd)
module = app:app
master = true
processes = 1
http = 0.0.0.0:5000
http-websockets = true
asyncio = eventlet
die-on-term = true
logto = /var/log/uwsgi/coopsoil.log
virtualenv = $(pwd)/.venv
touch-reload = $(pwd)/app.py
EOL

# Create the systemd service file
echo "Creating systemd service file..."
SERVICE_NAME="coopsoil.service"
sudo tee /etc/systemd/system/$SERVICE_NAME > /dev/null <<EOL
[Unit]
Description=CoopSoil Application Service
After=network.target

[Service]
User=$(whoami)
Group=$(id -gn)
WorkingDirectory=$(pwd)
ExecStart=/bin/bash -c 'source $(pwd)/.venv/bin/activate && sudo python3 $(pwd)/app.py'
Restart=always

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd daemon and enable the service
echo "Reloading systemd daemon and enabling the service..."
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME

echo "Setup completed! Reboot your Raspberry Pi to finalize."
sudo reboot
