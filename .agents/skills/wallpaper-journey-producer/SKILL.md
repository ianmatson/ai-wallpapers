---
name: wallpaper-journey-producer
description: Produce, validate, publish, or rehearse the daily Wallpaper Journey triptych and soundtrack from the local Linux workspace.
---

# Wallpaper Journey producer

Use this skill for an explicitly requested or scheduled production run, an isolated rehearsal, or validation and repair of today's release.

For every deterministic operation, use only `/home/ian/Documents/Codex/wallpaper-journey/ai-wallpapers/producer/wallpaper-producer`. It owns configuration, leases, immutable archives, upscaling, validation, publishing, and completion checks.

## Boundaries

- Production and publication require explicit authorization in the current request. A rehearsal uses only the isolated fixture and never publishes.
- Never bypass the wrapper, edit its archives directly, operate Upscayl, Vulkan, or the watcher, request broad host access, touch `consumer/` or the desktop wallpaper, or author repository changes during production.
- Obey wrapper conflicts. Never replace accepted artifacts. On failure, preserve the lease and artifacts and report the failed phase.
- The continuity journal is private narrative context. Never quote, attach, stage, publish, or otherwise expose it.
- Published GitHub Releases and their tags are permanent. Never prune them. Cleanup is local-only and remains governed by the local consumer or an explicit owner-approved local retention policy.
- Dedicated style references are the exclusive visual inputs to image generation. Previous journey images and the private journal may inform text-only continuity and recurring-element identity, but never attach either to image generation.
- Preserve the reference finish: smooth clean graphic digital landscape illustration; crisp designed silhouettes; simplified confident geometric forms; layered atmospheric planes; broad controlled color shapes; elegant flat-to-soft gradients; restrained selective detail; and clean edges. Reject photoreal or cinematic matte rendering and pervasive cellular, pebble, stipple, mosaic, impasto, canvas, crackle, dither, brush-grain, painterly-noise, or micro-detail textures.
- Choose an existing public Spotify playlist and preserve its exact returned metadata and URL. Never create a playlist or reconstruct its metadata.

## Production

1. Acquire or resume today's lease. Run `preflight` and `context`; if today's release is already complete, validate and report it without regenerating.
2. Read `continuity-log` and `references` within the boundaries above. Advance the journey visibly with a new event, place, or transformation, and avoid repeating yesterday's dominant composition.
3. Create the triptych as three adjacent crops of one continuous wide scene:
   - Before generation, plan each tile's role and joins, shared camera and perspective, lighting, what changes or stays fixed, and the total and per-tile allocation of recurring elements.
   - Generate the middle first. Accept it only when the composition works and both edges offer plausible continuations without awkwardly cutting important subjects.
   - Base each side prompt on the accepted middle's observed horizon, perspective, lighting, scale, edge geometry, and connecting features—not only on the original plan.
   - Always supply the middle as a clearly labeled spatial reference; add a crop of the relevant middle edge when useful. Generated panels are spatial references only. Dedicated style references remain the exclusive style source; express historical identity only in text.
   - For each side, state briefly what stays fixed, what crosses the seam, what is new, and what must not be duplicated.
   - Generate sides sequentially and inspect the assembled panorama after each candidate. Give the accepted panorama-so-far as context for the final side.
   - Accept panels only from the assembled triptych view. Check scene continuity, perspective, lighting, counts, recurring-element identity, tile distinctness, seam logic, text, logos, watermarks, the clean graphic finish, and prohibited texture drift. Regenerate a failed side with one targeted correction.
   Save candidates under the workspace `tmp/` directory, accept them through the wrapper, run `validate-native`, then `upscale` and inspect the results.
4. Accept one public story sentence. Select and validate a scene-appropriate Spotify playlist using exact public metadata. Run `stage`, inspect the release notes for privacy, then `publish` and `validate-release`.
5. After release validation, append one private continuity paragraph through the wrapper. Run `completion-check`, then `end-run`; ending the lease is forbidden before both release and journal presence validate.

On success, report the native, upscaled, and staging directories; release URL and asset names; Spotify title and public URL; story sentence; preview validation; and only whether the private journal entry exists.
