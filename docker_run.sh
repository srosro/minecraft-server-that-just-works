docker run -d \
  --name mc-server \
  --restart unless-stopped \
  -p 25565:25565 -p 25565:25565/udp \
  -p 19132:19132/udp \
  -v minecraft:/data \
  -v git-ssh-keys:/root/.ssh \
  -w /data \
  minecraft-server \
  java -Xms2G -Xmx8G -jar paper.jar nogui
