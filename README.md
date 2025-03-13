# Minecraft Server

## Running with Docker

### Prerequisites
- Docker installed on your system
- Git for version control

### Setup and Run
1. Clone this repository:
```bash
git clone https://github.com/srosro/minecraft-server.git
cd minecraft-server
```

2. Build the Docker image:
```bash
docker build -t minecraft-server .
docker volume create minecraft
```

3. Start server: `bash ./docker_run.sh`


# No longer needed:

Startup service
```
[Unit]
Description=Minecraft Paper Server
After=network.target

[Service]
User=odio
WorkingDirectory=/home/odio/minecraft-server
Type=simple
ExecStart=/usr/bin/java -Xms2G -Xmx6G -jar paper.jar nogui
Restart=on-failure

[Install]
WantedBy=multi-user.target
```
