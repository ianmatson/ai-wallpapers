# Daily production procedure

Use the absolute wrapper path returned by the saved project configuration. Begin by calling `wallpaper-producer begin-run` and retain the printed run ID. Invoke every workflow subcommand as `wallpaper-producer --run-id RUN_ID COMMAND ...`. Call `end-run RUN_ID` only after the release and private journal entry validate. A failed run deliberately keeps its lease; report the run ID so a supervised retry can resume it. All generated candidate files must first be saved under the workspace `tmp/` directory; the wrapper rejects inputs from elsewhere.

## 1. Establish state

1. Run `wallpaper-producer --run-id RUN_ID preflight`, then read the repository `README.md` and `producer/README.md`.
2. Run `context` for exact paths and today's tag.
3. Run `continuity-log` and use the complete journal only for narrative continuity, recurring-object identity, and unresolved hooks. Never quote it in reports or prompts.
4. If today's public release already exists, validate it before doing new work. Reuse valid local and public artifacts; stop on contradictions.
5. Run `references`. Visually inspect every style reference. Separately inspect historical context only for narrative/geographic facts. Convert relevant history into a concise text-only brief under `tmp/`; do not attach historical frames or the journal to image generation.

## 2. Generate and accept the triptych

Plan one continuous 48:9 panorama cut into adjacent left, middle, and right 16:9 windows. Keep a single horizon, camera height, projection, lighting direction, atmosphere, scale, and palette. Place important landmarks in explicit spans so they are not duplicated or reframed across panels.

The standing finish is a clean graphic digital landscape: crisp silhouettes, simplified geometric forms, layered atmospheric planes, controlled broad color shapes, flat-to-soft gradients, restrained detail, and clean edges. Reject text, logos, watermarks, signatures, borders, duplicated landmarks or suns, broken seams, incompatible perspective, and cellular, honeycomb, pebble, stippled, mosaic, impasto, canvas, crackle, dither, brush-grain, painterly-noise, or pervasive micro-detail texture.

1. Generate the middle panel first using the style references and text-only continuity brief.
2. Visually inspect it. Generate left using the accepted middle only as spatial/boundary context; style still comes exclusively from the style references.
3. Visually inspect both. Generate right using accepted middle and left only as spatial/boundary context.
4. Inspect each panel and the left-to-right panorama. Regenerate before acceptance if seams, perspective, subject allocation, texture, or style fail.
5. Save each accepted PNG under `tmp/`, then call `accept-native middle|left|right FILE`. Run `validate-native` after all three are accepted.

Never overwrite an existing native file. If all three already exist, validate and visually inspect them instead.

## 3. Upscale and review

Run `upscale`. It must use the configured `digital-art-4x` model, verify model hashes, produce exact 4x dimensions, and atomically archive outputs. Visually inspect all three upscaled PNGs and the panorama. Stop if upscaling introduces grain, texture, corruption, or seam problems.

## 4. Story and soundtrack

Write one concise public story sentence under `tmp/` and accept it with `accept-story FILE`.

Choose an existing public Spotify playlist. Derive at least three scene-specific sonic anchors across setting, instrumentation/texture, energy, and emotion. Search using a connected Spotify capability when available, otherwise web search and public Spotify pages. Avoid generic focus/study/peaceful-piano catalogs unless uniquely appropriate.

For each serious candidate, preserve the exact returned `title`, `creator`, `type`, `uri`, `url`, `playable_status`, and `search_query` in a new JSON file under `tmp/`. Run `inspect-playlist FILE`; require the exact public page and matching Spotify oEmbed metadata. Run `validate-playlist FILE` only for the selected candidate. Never reconstruct or normalize a URL.

## 5. Publish, validate, and journal

1. Run `stage` and inspect the deterministic release notes. Confirm they contain no private-journal material.
2. Run `publish`. It must validate exactly three JPEG assets, embedded public previews, the Spotify URL and app URI, and retention behavior.
3. Only after `validate-release` succeeds, write one substantive private continuity paragraph under `tmp/`. Record narrative events, concrete state/appearance of recurring objects or locations, transformations, new elements, and open hooks without style guidance.
4. Run `append-continuity-log FILE`. Never edit the journal manually and never append a duplicate date.
5. Run `completion-check`, then `end-run RUN_ID`. The wrapper independently repeats the completion check before it removes the lease.

On success report the three local directories, release URL, exact asset names, Spotify title and public URL, public story sentence, preview validation, and whether the private entry exists—without quoting the entry.
