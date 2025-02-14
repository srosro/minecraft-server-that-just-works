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
