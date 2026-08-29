---
name: wallpaper-journey-producer
description: Produce, validate, publish, and privately journal the daily Wallpaper Journey triptych and soundtrack from the local Linux workspace.
---

# Wallpaper Journey producer

Use this skill only for an explicitly requested or scheduled Wallpaper Journey production run, supervised rehearsal, or validation/repair of today's release.

The reviewed entrypoint is `producer/wallpaper-producer`. It loads the owner-only configuration, enforces a per-date run lease plus a command lock, and delegates to the deterministic pipeline. Never bypass it with direct archive edits.

## Hard boundaries

- Production publishing is authorized only when the current request or scheduled-task prompt explicitly says to run production. Rehearsals must use a fixture date/state and must not publish.
- Never overwrite or delete native, upscaled, staging, or revision artifacts. Reuse valid artifacts; stop on conflicts.
- Never quote, stage, upload, or attach the private continuity journal. Read it only for narrative facts. Historical frames are also narrative context only and must never be passed to image generation.
- Dedicated style references are the exclusive source of visual style.
- Never create a Spotify playlist or fabricate/normalize its metadata or URL.
- Never invoke files under `consumer/`, inspect the desktop wallpaper, or change it.
- Do not author repository changes during a daily production run.

For a daily production run or supervised rehearsal, read [references/daily-run.md](references/daily-run.md) and follow it. Preserve accepted artifacts on failure and report the failed phase and normalized error without exposing private context or credentials.
