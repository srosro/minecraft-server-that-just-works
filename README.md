# minecraft-server-that-just-works

A Minecraft server that **Java and Bedrock players can both join**, packaged so that
updating and running it is a single instruction.

Say this to Claude and it should take you all the way to a running, current server:

> update and run https://github.com/srosro/minecraft-server-that-just-works

The world, the plugins, and all the config live in this repo, so your save travels
with it. On its **first** start the Paper jar downloads the Mojang server jar and
~100 MB of libraries, so that boot needs internet and takes a few minutes; every
start after that is seconds.

---

## What you get

| | |
|---|---|
| Server | Paper (Minecraft Java Edition) |
| Bedrock support | Geyser + Floodgate — phones, tablets, consoles, Windows |
| Java port | **25565/tcp** |
| Bedrock port | **19132/udp** |
| Runtime | Docker, repo bind-mounted at `/minecraft` |

Bedrock players join through Geyser, and Floodgate lets them in without a Java account.

---

## Requirements

- **Docker**, with your user in the `docker` group:
  ```bash
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"     # log out and back in
  ```
- **~5 GB of free RAM** — the container is capped at 5 GB with a 4 GB heap. Running
  a smaller host means lowering both `--memory` in `docker_run.sh` and `-Xmx` in the
  Dockerfile's `CMD` together; the cap must stay above the heap or the kernel
  OOM-kills the server mid-save.
- Ports `25565/tcp` and `19132/udp` reachable — see [Networking](#networking)

---

## Run it

```bash
git clone https://github.com/srosro/minecraft-server-that-just-works.git
cd minecraft-server-that-just-works
docker build -t minecraft-server .
./docker_run.sh
```

That's the whole thing. The container restarts on boot and on crash
(`--restart unless-stopped`).

The first start is slow and quiet while it fetches libraries — watch it with
`docker logs -f mc-server` and wait for `Done (…)! For help, type "help"`.

```bash
docker logs -f mc-server        # watch the console
docker stop -t 90 mc-server     # stop (waits for a clean world save)
docker start mc-server          # start the same container again
./docker_run.sh                 # rebuild the container (after a config/image change)
```

**Always stop with `docker stop -t 90`.** Minecraft flushes the world on shutdown, and
a short timeout can cut that off mid-write and corrupt chunks. `docker_run.sh` replaces
any existing container, so stop cleanly *before* re-running it.

---

## Updating to the latest Minecraft

Minecraft Java moved to calendar versioning: releases now look like `26.2`, not `1.21.4`.
Four things move together, and **they must be consistent** or the server won't boot:

| Piece | Where it comes from |
|---|---|
| `paper.jar` | `https://fill.papermc.io/v3/projects/paper` |
| `plugins/Geyser-Spigot.jar` | `https://download.geysermc.org/v2/projects/geyser` |
| `plugins/Floodgate-Spigot.jar` | `https://download.geysermc.org/v2/projects/floodgate` |
| Java version in `Dockerfile` | `https://piston-meta.mojang.com/mc/game/version_manifest_v2.json` → `javaVersion.majorVersion` |

The two constraints that bite:

1. **Geyser emulates a specific Java client version.** Geyser 2.11.x emulates a `26.2`
   client, so Paper must be `26.2`. An older Paper needs ViaVersion as well — simpler to
   just keep Paper current.
2. **Each Minecraft release pins a Java version.** MC 26.2 requires **Java 25**, so the
   Dockerfile is on `eclipse-temurin:25-jre-noble`. Paper refuses to start on a Java
   release newer than it was built against, so this is not a "newer is safer" choice —
   match it exactly.

To check what Bedrock client versions the current Geyser accepts:

```bash
unzip -p plugins/Geyser-Spigot.jar \
  org/geysermc/geyser/network/GameProtocol.class | strings | grep -oE '^26\.[0-9]+$' | sort -uV
```

> The Geyser wiki's "supported versions" page lags its releases. Trust the jar, not the page.

**Back up the world before any version jump.** Minecraft upgrades world format on load
and it is one-way:

```bash
tar czf ~/mc-backup-$(date +%F).tar.gz world world_nether world_the_end plugins paper.jar
```

---

## Networking

The server needs two ports reachable from the internet, and **the protocols differ** —
this is the single most common way to end up with "Java works, Bedrock doesn't":

| Edition | Port | Protocol |
|---|---|---|
| Java | 25565 | **TCP** |
| Bedrock | 19132 | **UDP** |

Forward both on your router to the machine running the server, and give that machine a
**DHCP reservation** — the rules point at a fixed IP and break silently if its lease changes.

Verify from outside your network (not from the LAN, which can succeed via hairpinning
even when forwarding is broken):

```bash
./scripts/mcping.py <public-ip-or-hostname> java
./scripts/mcping.py <public-ip-or-hostname> bedrock
```

### DNS (manual, on purpose)

DNS is **not** automated here — it's tied to whoever owns the domain. If you want a
hostname instead of a bare IP:

- Add an **A record** pointing at your public IP.
- On a residential connection that IP changes, so pair it with dynamic DNS.
  `scripts/ddns-update.sh` handles the Namecheap flavour: enable Dynamic DNS on the
  domain, put the generated password in `~/.config/namecheap-ddns.pass` (mode 600),
  and run it from a timer.
- Java clients can then use the bare hostname (25565 is their default port). **Bedrock
  clients must be given the port explicitly** — there's no SRV fallback.

---

## What to tell players

After setup, hand out exactly this:

```
Java Edition:      <host>            (port 25565 — the default, usually auto-filled)
Bedrock / iOS /
Windows / console: <host>  port 19132
```

Bedrock players must type the port manually. Java players usually don't.

---

## Layout

```
paper.jar            the server
world/ world_nether/ world_the_end/   saves (tracked in git — this repo IS the backup)
plugins/             Geyser, Floodgate, spark
server.properties    MOTD, difficulty, whitelist, player cap
Dockerfile           pins the Java version Minecraft requires
docker_run.sh        the one command that starts it
scripts/             ping checker + dynamic DNS updater
```

`versions/`, `libraries/`, `cache/` and `logs/` are regenerated by Paper on every start
and are deliberately **not** tracked.
