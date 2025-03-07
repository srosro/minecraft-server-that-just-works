# Use an official OpenJDK base image
#FROM openjdk:17-jre-slim
FROM openjdk:21-slim-bullseye

# Set the working directory
WORKDIR /minecraft

# Expose the default Minecraft server port
EXPOSE 25565 19132

RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    vim \
    nmap \
    procps \
    git

# Accept the EULA (set to true in the eula.txt file)
RUN echo "eula=true" > /minecraft/eula.txt

# Run the Minecraft Paper server with the specified memory options
CMD ["java", "-Xms2G", "-Xmx8G", "-jar", "paper.jar", "nogui"]
