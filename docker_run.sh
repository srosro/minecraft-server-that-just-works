docker run -d \
  --name mc-server \
  --restart unless-stopped \
  --user 1000:1000 \
  -p 25565:25565 -p 25565:25565/udp \
  -p 19132:19132/udp \
  -v minecraft:/minecraft \
  -v docker-ssh-keys:/home/docker/.ssh \
  -w /minecraft \
  minecraft-server \
  java -Xms2G -Xmx8G -jar paper.jar nogui