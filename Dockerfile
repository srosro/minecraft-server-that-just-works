# Java 25 -- the version Minecraft 26.2 pins. Paper refuses to start on a Java
# release newer than it was built against, so this tracks the server version
# rather than "latest". Temurin publishes arm64, which the Raspberry Pi needs.
FROM eclipse-temurin:25-jre-noble

# The server itself needs nothing but a JRE. No shell tooling is installed on
# purpose: this process is exposed to the internet and runs third-party plugins.
WORKDIR /minecraft
ENV HOME=/minecraft

EXPOSE 25565 19132/udp

# Unprivileged. docker_run.sh overrides this with the invoking user's uid:gid so
# that bind-mounted world files stay writable from the host.
USER 1000:1000

# The single home for heap settings -- docker_run.sh forwards "$@" rather than
# repeating this, so the two cannot drift.
CMD ["java", "-Xms2G", "-Xmx4G", "-jar", "paper.jar", "nogui"]
