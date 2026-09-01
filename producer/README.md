# Producer operator reference

This is human-facing setup and recovery documentation. Routine scheduled production loads the project skill and uses the wrapper help; it does not require this file as model context.

`wallpaper-producer` is the only production entrypoint. It loads the owner-only configuration, acquires a per-date lease and command lock, and delegates deterministic work to `pipeline.zsh`. Do not invoke the pipeline directly in production.

## Configuration

Copy `wallpaper.env.example` outside the public repository, replace its placeholders with absolute paths, and set mode `0600`. Store the fine-grained GitHub token in the separately configured token file, also outside the repository and mode `0600`; never put the token in the environment file, prompts, logs, or repository.

The wrapper rejects unsafe ownership, permissions, paths, dates, overlapping runtime roots, unexpected Git state, or the wrong GitHub identity. Agent-created inputs are accepted only from `AI_WALLPAPERS_INPUT_ROOT`.

Current Linux production intentionally uses watcher-mode upscaling. The wrapper queues each native panel, waits within the configured timeout, validates exact 4x dimensions, and atomically archives the result. Operators and agents must not start or control the watcher, Vulkan, or Upscayl directly. Direct mode remains available for configured hosts and isolated tests.

## Run lifecycle

```sh
producer/wallpaper-producer begin-run RUN_ID
producer/wallpaper-producer --run-id RUN_ID preflight
producer/wallpaper-producer --run-id RUN_ID context
producer/wallpaper-producer --run-id RUN_ID references
producer/wallpaper-producer --run-id RUN_ID continuity-log
# generate and accept images, story, and playlist through the remaining commands
producer/wallpaper-producer --run-id RUN_ID stage
producer/wallpaper-producer --run-id RUN_ID publish
producer/wallpaper-producer --run-id RUN_ID append-continuity-log FILE
producer/wallpaper-producer --run-id RUN_ID completion-check
producer/wallpaper-producer end-run RUN_ID
```

Every workflow command requires the owning run ID. If a lease already exists, resume that exact ID. A failed run deliberately keeps its lease and accepted artifacts. `end-run` independently repeats the completion check and releases the lease only after the public release and today's private journal entry validate.

Run `producer/wallpaper-producer help` for the complete command list. Routine commands validate and reuse existing artifacts or stop on conflicts; they do not overwrite native, upscaled, staged, soundtrack, or journal records.

## Responsibilities and privacy

The agent supplies visual judgment, image generation and review, the public story sentence, and selection of an existing public Spotify playlist. The wrapper handles paths, immutable acceptance, image validation, upscaling, release notes, GitHub publication, public Spotify validation, release-asset digest checks, retention, append-only journaling, and final completion.

`references` separates dedicated style references from prior journey images. Style references define rendering style. Prior images may preserve the visual identity of specific recurring elements, but must not control the new scene's overall composition or style.

The continuity journal is stored outside the public repository and staging tree. It is append-only by date and must never be quoted, staged, uploaded, or attached to image generation.

## Recovery and validation

Soundtrack rerolls use `replace-playlist`, followed by `stage` and `publish`; prior revisions remain archived. Supervised image corrections use revision roots and `replace-release-assets`, which requires and revalidates exactly the three expected release assets.

Run `../tests/linux-producer.zsh` for the isolated deterministic fixture and `producer/wallpaper-producer doctor` for read-only host readiness. The fixture must pass before production changes are activated.
