# Use an official OpenJDK base image
FROM openjdk:21-slim-bullseye

# Set environment variables
ENV MINECRAFT_USER=docker \
    MINECRAFT_UID=1000 \
    MINECRAFT_GID=1000

# Install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    vim \
    nmap \
    procps \
    git \
    sudo && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create the minecraft user
RUN groupadd -g ${MINECRAFT_GID} ${MINECRAFT_USER} && \
    useradd -u ${MINECRAFT_UID} -g ${MINECRAFT_GID} -m -s /bin/bash ${MINECRAFT_USER} && \
    echo "${MINECRAFT_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${MINECRAFT_USER} && \
    chmod 0440 /etc/sudoers.d/${MINECRAFT_USER}

# Create minecraft directory and set permissions
RUN mkdir -p /minecraft && \
    chown -R ${MINECRAFT_USER}:${MINECRAFT_USER} /minecraft

# Set the working directory
WORKDIR /minecraft

# Accept the EULA (set to true in the eula.txt file)
RUN echo "eula=true" > /minecraft/eula.txt && \
    chown ${MINECRAFT_USER}:${MINECRAFT_USER} /minecraft/eula.txt

# Expose the default Minecraft server ports
EXPOSE 25565 19132

# Switch to the minecraft user
USER ${MINECRAFT_USER}

# Create an entrypoint script
RUN echo '#!/bin/bash\n\
# Fix SSH key permissions if SSH keys are mounted\n\
if [ -d "/home/docker/.ssh" ]; then\n\
  sudo chown -R docker:docker /home/docker/.ssh\n\
  chmod 700 /home/docker/.ssh\n\
  find /home/docker/.ssh -type f -exec chmod 600 {} \\;\n\
  find /home/docker/.ssh -name "*.pub" -exec chmod 644 {} \\;\n\
fi\n\
\n\
# Run the server with the provided arguments\n\
exec "$@"\n' > /home/docker/entrypoint.sh && \
    chmod +x /home/docker/entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/home/docker/entrypoint.sh"]

# Default command to run the server
CMD ["java", "-Xms2G", "-Xmx8G", "-jar", "paper.jar", "nogui"]