#!/bin/bash

# =============================================================
# Install and Configure SonarQube with PostgreSQL on Ubuntu
# =============================================================

# Update and Upgrade System Packages
    echo "Updating system packages..."
    sudo apt update -y

# =============================================================
# Install and Configure PostgreSQL
# =============================================================

# Add PostgreSQL Repository
    echo "Adding PostgreSQL repository..."
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    wget -qO- https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo tee /etc/apt/trusted.gpg.d/pgdg.asc &>/dev/null

# Install PostgreSQL
    echo "Installing PostgreSQL..."
    sudo apt update
    sudo apt install -y postgresql postgresql-contrib
    sudo systemctl enable postgresql.service
    sudo systemctl start postgresql.service

# Configure PostgreSQL for SonarQube
    echo "Configuring PostgreSQL for SonarQube..."
    sudo echo "postgres:admin123" | sudo chpasswd
    sudo runuser -l postgres -c "createuser sonar"
    sudo -i -u postgres psql -c "ALTER USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
    sudo -i -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
    sudo -i -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Restart PostgreSQL
    echo "Restarting PostgreSQL..."
    sudo systemctl restart postgresql.service

# Check PostgreSQL Status and Listening Ports
    echo "Checking PostgreSQL status..."
    sudo systemctl status -l postgresql.service
    echo "Checking PostgreSQL listening ports..."
    netstat -tulpena | grep postgres

# =============================================================
# Install and Configure SonarQube
# =============================================================

# Install Java 17 (Adoptium Temurin)
    echo "Installing Java 17..."
    wget -O - https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo tee /etc/apt/keyrings/adoptium.asc
    echo "deb [signed-by=/etc/apt/keyrings/adoptium.asc] https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | sudo tee /etc/apt/sources.list.d/adoptium.list
    sudo apt update
    sudo apt install -y temurin-17-jdk
    java --version

# Configure Linux Kernel Parameters
    echo "Configuring Linux kernel parameters..."
    sudo bash -c 'echo "sonarqube   -   nofile   65536" >> /etc/security/limits.conf'
    sudo bash -c 'echo "sonarqube   -   nproc    4096" >> /etc/security/limits.conf'
    sudo bash -c 'echo "vm.max_map_count = 262144" >> /etc/sysctl.conf'
    sudo sysctl -p

# Download and Extract SonarQube
    echo "Downloading and extracting SonarQube..."
    sudo apt install -y wget unzip
    sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
    sudo unzip sonarqube-9.9.0.65466.zip -d /opt
    sudo mv /opt/sonarqube-9.9.0.65466 /opt/sonarqube

# Create SonarQube User and Set Permissions
    echo "Creating SonarQube user and setting permissions..."
    sudo groupadd sonar
    sudo useradd -c "SonarQube user" -d /opt/sonarqube -g sonar sonar
    sudo chown -R sonar:sonar /opt/sonarqube

# Configure SonarQube Database Connection
    echo "Configuring SonarQube database connection..."
    sudo bash -c 'cat <<EOT > /opt/sonarqube/conf/sonar.properties
    sonar.jdbc.username=sonar
    sonar.jdbc.password=admin123
    sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
    EOT'

# Create Systemd Service for SonarQube
    echo "Creating systemd service for SonarQube..."
    sudo bash -c 'cat <<EOT > /etc/systemd/system/sonar.service
    [Unit]
    Description=SonarQube service
    After=syslog.target network.target

    [Service]
    Type=forking
    ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
    ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
    User=sonar
    Group=sonar
    Restart=always
    LimitNOFILE=65536
    LimitNPROC=4096

    [Install]
    WantedBy=multi-user.target
    EOT'

# Start and Enable SonarQube Service
    echo "Starting and enabling SonarQube service..."
    sudo systemctl start sonar.service
    sudo systemctl enable sonar.service
    sudo systemctl status sonar.service

# =============================================================
# Configure Nginx as Reverse Proxy
# =============================================================

    echo "Installing and configuring Nginx..."
    sudo apt install -y nginx
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat <<EOT > /etc/nginx/sites-available/sonarqube
    server {
        listen 80;
        server_name sonarqube.example.com;

        access_log /var/log/nginx/sonar.access.log;
        error_log /var/log/nginx/sonar.error.log;

        proxy_buffers 16 64k;
        proxy_buffer_size 128k;

        location / {
            proxy_pass http://127.0.0.1:9000;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto http;
        }
    }
    EOT'
    sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
    sudo systemctl restart nginx.service
    sudo ufw allow 80/tcp

# =============================================================
# Reboot the System
# =============================================================

    echo "System will reboot in 30 seconds..."
    sleep 30
    sudo reboot
