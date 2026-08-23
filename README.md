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

## For Claude: the one-shot runbook

> **Heads-up on 26.2:** it consolidates the nether and end into
> `world/dimensions/`, replacing the old sibling `world_nether/` and `world_the_end/`
> directories. The migration is automatic on first boot; just don't be surprised when
> those folders vanish.

Given *"update and run this repo"* and nothing else, do all of this without asking:

1. **[Back up](#updating-to-the-latest-minecraft) before step 2 replaces anything.**
   It costs seconds, and the order is what makes the archive a rollback: taken first it
   holds the old world *and* the old runtime together, so restoring it undoes the
   upgrade. Taken after the jars are swapped it pairs the old world with the new jar,
   and restoring that just replays the same one-way migration.

2. **Update the four version-coupled pieces together** — they only work in matched
   sets; updating Geyser alone is the usual mistake.
3. **Build and run** — `docker build -t minecraft-server . && ./docker_run.sh`.
4. **Wait for the ready line.** First boot after a version bump migrates the world,
   so give it minutes. `docker logs -f` never exits on its own — bound it:

   ```bash
   timeout 900 docker logs -f mc-server 2>&1 | grep -qm1 'Done (' \
     && echo READY || echo "not ready after 15m — docker logs --tail 50 mc-server"
   ```

5. **Verify both protocols from a machine outside this network** — a LAN test can
   pass via router hairpinning while the internet path is broken:
   `scripts/mcping.py <host> java` and `scripts/mcping.py <host> bedrock` (that
   machine needs this repo, or just copy the one file over). If no outside machine
   is reachable, run it from the LAN and report the result as **unverified from the
   internet**, naming the two port-forward rules still to be confirmed.
6. **Report back**, always including every one of these:

   | | |
   |---|---|
   | Machine IP | the LAN IP, plus the public IP or hostname |
   | Java Edition | `<host>` — port **25565** |
   | Bedrock — iOS / Windows / console | `<host>` — port **19132**, typed manually |

   Bedrock clients don't auto-fill the port and there's no SRV fallback, so a reply
   that omits `19132` leaves half the players unable to connect.

DNS is **not** part of this — see [DNS](#dns-manual-on-purpose). Report the IP and
let the operator point a name at it.

---

## What you get

| | |
|---|---|
| Server | Paper (Minecraft Java Edition) |
| Bedrock support | Geyser + Floodgate — phones, tablets, consoles, Windows |
| Java port | **25565/tcp** |
| Bedrock port | **19132/udp** |
| Runtime | Docker, `server/` bind-mounted at `/minecraft` |

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
  OOM-kills the server mid-save. **On Raspberry Pi OS that cap does nothing until
  you enable it — see below.**
- Ports `25565/tcp` and `19132/udp` reachable — see [Networking](#networking)

### Raspberry Pi: the memory cap needs enabling

Raspberry Pi OS ships without the memory cgroup, so `--memory=5g` is **silently
discarded**:

```
WARNING: Your kernel does not support memory limit capabilities or the cgroup
is not mounted. Limitation discarded.
```

`-Xmx` still bounds the heap, but nothing bounds the container, so an overrun
lets the kernel pick the OOM victim by score — which may be something else on the
Pi rather than the server. Enable it with:

```bash
# cmdline.txt must stay ONE line -- the bootloader reads only the first, so this
# appends to the existing line rather than adding a new one.
sudo sed -i '1 s/$/ cgroup_enable=memory cgroup_memory=1/' /boot/firmware/cmdline.txt
sudo reboot
```

On Pi OS older than Bookworm the file is `/boot/cmdline.txt` — editing the
Bookworm path there lands in a file the bootloader never reads.

Confirm it took, after the reboot:

```bash
docker info --format '{{.MemoryLimit}}'   # true = cap enforced, false = still ignored
```

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
scripts/stop-server.sh          # stop (waits for a clean save, refuses if torn)
docker start mc-server          # start the same container again
./docker_run.sh                 # recreate the container (after docker build, or
                                #   a docker_run.sh change; stops cleanly first)
```

Heap lives in one place — the `CMD` in the `Dockerfile`. Change it there and rebuild;
raising it past `--memory` in `docker_run.sh` is what causes the OOM kill above.

**Always stop with `scripts/stop-server.sh`.** Minecraft flushes the world on shutdown,
and a raw `docker stop` escalates to SIGKILL once its timeout expires *and still reports
success* — so it can tear a world mid-save and tell you it went fine. The script waits,
then checks whether the shutdown was actually clean and refuses to hand you a torn
world. `docker_run.sh` and `scripts/backup-world.sh` both run it.

Editing `server/server.properties`, the world, or anything under `server/plugins/` needs **no** recreate
— it's all bind-mounted. Just `scripts/stop-server.sh && docker start mc-server`.

---

## Updating to the latest Minecraft

Minecraft Java moved to calendar versioning: releases now look like `26.2`, not `1.21.4`.
Four things move together, and **they must be consistent** or the server won't boot:

| Piece | Where it comes from |
|---|---|
| `server/paper.jar` | `https://fill.papermc.io/v3/projects/paper` |
| `server/plugins/Geyser-Spigot.jar` | `https://download.geysermc.org/v2/projects/geyser` |
| `server/plugins/Floodgate-Spigot.jar` | `https://download.geysermc.org/v2/projects/floodgate` |
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
unzip -p server/plugins/Geyser-Spigot.jar \
  org/geysermc/geyser/network/GameProtocol.class | strings | grep -oE '^26\.[0-9]+$' | sort -uV
```

> The Geyser wiki's "supported versions" page lags its releases. Trust the jar, not the page.

**Back up the world before any version jump.** Minecraft upgrades world format on load
and it is one-way. Stop the server first — tarring a running world captures it
mid-write:

```bash
scripts/backup-world.sh        # stops the server, tars, prints the archive path
```

It refuses to run if the server won't stop — tarring a live world captures it
mid-write. The archive carries the `Dockerfile` alongside the jar, because Paper
won't start on a Java newer than it was built against, so a rollback has to move the
pin and the jar together.

**Restoring is deliberately manual** — it runs once a year at most, and an automated
version has to delete the live world before the old one is safely back.

The archive holds `world*/`, `plugins/`, `paper.jar` and the `Dockerfile` as they were
at one moment, so putting all four back gives a consistent server — the `Dockerfile`
matters because it pins the Java version that jar needs.

Stop the server first (`scripts/stop-server.sh`), and when everything is in place
rebuild and start it (`docker build -t minecraft-server . && ./docker_run.sh`) — the
`Dockerfile` you just restored only takes effect on a rebuild. In between, three
things to get right: unpack the archive somewhere scratch and check it *before*
touching the live tree; **replace** the world directories rather than untarring over
them, since merging leaves new-format chunks beside an old `level.dat`; and note the
`Dockerfile` is a top-level member of the archive, so it belongs at the repo root, not
under `server/`.

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
- On a residential connection that IP changes, so pair it with your registrar's
  dynamic DNS and a timer. Keep that updater **outside this repo entirely** — it holds
  your registrar credentials and this tree is public. `server/` is doubly wrong: the
  server's plugins can write there.
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
server/              THE ONLY THING MOUNTED INTO THE CONTAINER
  paper.jar          the server
  world/             the save, all dimensions (tracked in git — this repo IS the backup)
  plugins/           Geyser, Floodgate, spark
  server.properties  MOTD, difficulty, whitelist, player cap

Dockerfile           pins the Java version Minecraft requires   ─┐ read and executed
docker_run.sh        the one command that starts it              │ on the HOST, so
scripts/             ping checker, backup, clean stop              │ deliberately kept
README.md            this file, and the runbook agents follow   ─┘ out of the mount
```

That split is load-bearing, not tidiness. The server is exposed to the internet and
runs third-party plugin code; anything it can write is something it can hand back to
the host to execute — a script you run, or a runbook an agent follows. Put host-read
files at the root and server-owned state under `server/`, and there's no allowlist to
keep in sync.

`server/versions/`, `server/libraries/`, `server/cache/` and `server/logs/` are
regenerated by Paper on every start and are deliberately **not** tracked.
