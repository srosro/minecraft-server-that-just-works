# Review instructions — minecraft-server-that-just-works

Repo-specific reviewer policy. The universal review policy is prepended by the
reviewer and is not restated here.

## What this repo is

A Minecraft (Paper) server that Java and Bedrock players can both join,
packaged as a Docker image plus a one-shot runbook in `README.md` so "update
and run this repo" takes an agent to a running, current server. The world,
plugins and config live in the repo.

**Stage:** internal. A family/friends server run from a local checkout.

## Review bar

Report **Critical** and **Important** findings only. Nits and style go
unmentioned.

- **No security against coworkers.** Everyone with push access, and our own
  agents, are trusted. Do not propose guards or validation against them.
- **Simplest code wins.** Prefer deletion and inlining over new guards,
  fallbacks or abstractions for cases that cannot happen at this scale.

## Where the real risks are

- **The world is the data.** Flag a change that can upgrade or overwrite
  `server/` world data without the backup the runbook requires first.
- **Version-coupled pieces.** The four pieces the runbook updates together must
  move together; flag a bump of one alone.
