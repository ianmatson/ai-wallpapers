# Producer pipeline

`pipeline.zsh` handles the deterministic parts of the daily release workflow.
The Codex automation remains responsible for the work that needs judgment:

- inspecting the reference images and choosing the next visual direction;
- generating and visually reviewing the triptych;
- writing the one-sentence story;
- searching Spotify and choosing an appropriate existing public playlist.

Everything else is exposed as small, idempotent commands. On Linux, invoke
them through the lock-protected wrapper:

```sh
producer/wallpaper-producer doctor
producer/wallpaper-producer begin-run wall-2099-01-02-example
producer/wallpaper-producer --run-id wall-2099-01-02-example preflight
producer/wallpaper-producer --run-id wall-2099-01-02-example references
producer/wallpaper-producer --run-id wall-2099-01-02-example continuity-log
producer/wallpaper-producer --run-id wall-2099-01-02-example accept-native middle /workspace/tmp/middle.png
producer/wallpaper-producer --run-id wall-2099-01-02-example accept-story /workspace/tmp/story.txt
producer/wallpaper-producer --run-id wall-2099-01-02-example upscale
producer/wallpaper-producer --run-id wall-2099-01-02-example stage
producer/wallpaper-producer --run-id wall-2099-01-02-example publish
producer/wallpaper-producer --run-id wall-2099-01-02-example append-continuity-log /workspace/tmp/continuity-entry.txt
producer/wallpaper-producer --run-id wall-2099-01-02-example completion-check
producer/wallpaper-producer end-run wall-2099-01-02-example
```

Copy `wallpaper.env.example` outside the repository, replace every placeholder
with an absolute path, and set mode `0600`. The wrapper loads that file with
automatic export and rejects an unsafe configuration mode. `begin-run` creates
an atomic per-date lease, every workflow command must present the owning run
ID, and `end-run` releases it only after successful validation and journaling.
A separate nonblocking `flock` prevents command-level races. A failed run keeps
its lease so it can be resumed with the same ID without letting a second run
interleave. Agent-created inputs are accepted only from the configured
`AI_WALLPAPERS_INPUT_ROOT`.

GitHub API and release access uses a separate fine-grained personal access
token file configured by `AI_WALLPAPERS_GITHUB_TOKEN_FILE`. Keep it outside the
repository, owned by the runtime user, and mode `0600`. The wrapper requires a
`github_pat_` token and exports it to child commands as `GH_TOKEN`; never place
the token itself in `wallpaper.env`, logs, prompts, or repository files.

## Reference roles

`references` returns two deliberately separate groups:

- `style_references` comes only from
  the configured `story/style-references` root. These files
  are the exclusive source of rendering style, shape language, palette
  handling, and texture.
- `historical_context` comes only from prior native story frames. Codex reviews
  these for narrative and continuity context, translates that context into
  words, and never passes the historical image files to the image generator.

This boundary prevents rendering artifacts or incidental style drift in prior
generations from becoming self-reinforcing.

## Private continuity journal

The agent-only narrative journal lives under the configured private root as
`daily-continuity-log.md`.
It is outside the repository, release staging tree, and GitHub release assets.
Future runs read it with `producer/wallpaper-producer --run-id RUN_ID continuity-log` as narrative and
object-identity context only; it is never a source of visual style.

After a successful release, Codex writes one substantive paragraph to a new
temporary file and runs `producer/wallpaper-producer --run-id RUN_ID append-continuity-log FILE`.
Entries summarize the day's events, concrete appearance and state of recurring
objects or places, newly introduced elements, and unresolved story hooks. The
command is append-only by date, rejects headings and multi-paragraph entries,
and stores the journal with private filesystem permissions. It is never staged
or published.

Run `producer/wallpaper-producer --run-id RUN_ID context` for the current tag and exact archive paths.
The automation writes its selected playlist candidate to a new temporary JSON
file and its story sentence to the returned `story_file` path. The playlist
validator rejects duplicate or publicly unresolvable playlists before it
creates the accepted `spotify-playlist.json`. Generative-search results are
allowed when their exact public page and Spotify oEmbed metadata both validate.
`inspect-playlist` also returns Spotify's public playlist description so Codex
can judge specificity and ambiance rather than relying on a generic title.

An explicit soundtrack reroll is append-only:

```sh
producer/wallpaper-producer --run-id RUN_ID replace-playlist /workspace/tmp/better-candidate.json
producer/wallpaper-producer --run-id RUN_ID stage
producer/wallpaper-producer --run-id RUN_ID publish
```

That creates numbered `spotify-playlist-rN.json` and `release-notes-rN.txt`
revisions. Prior choices and notes remain untouched while the release body is
updated to the newest validated revision.

The script never overwrites an existing native, upscaled, or staged artifact.
On a rerun it validates and reuses good artifacts, and stops on a conflict.
`publish` also validates the release assets, embedded image previews, public
Spotify page and oEmbed metadata before applying the 30-release retention rule.
Release notes include an official HTTPS link labeled `Open in Spotify` plus the
exact copyable `spotify:playlist:<playlist-id>` app URI. GitHub strips custom
`spotify:` hyperlinks from rendered Markdown, so the HTTPS link provides the
clickable app handoff while the URI remains available for direct use. The
validator requires the URL and URI to identify the same playlist and requires
both exact values in the published release body.

When a published day's imagery must be corrected, archive the correction under
new local revision roots, stage it there, and run
`producer/wallpaper-producer --run-id RUN_ID replace-release-assets`. The command requires an existing
release with exactly the three expected assets, replaces only those assets with
the validated staged files, updates the notes, and revalidates the release.

## Linux image tools and Upscayl

Image inspection and JPEG staging use ImageMagick (`magick`, or
`identify`/`convert` on ImageMagick 6). macOS continues to use `sips` when
available. Modification times use BSD or GNU `stat` as appropriate.

Linux upscaling runs the configured Upscayl NCNN executable synchronously. It
verifies the configured `digital-art-4x.bin` and `.param` hashes before each
run, requires a hardware Vulkan device and scale 4, enforces a bounded timeout,
writes each job to a unique work directory, validates the exact output
dimensions, and atomically creates the output and archive files without
overwrite. The previous macOS watcher mode remains available by setting
`AI_WALLPAPERS_UPSCAYL_MODE=watcher`.

For safe isolated tests, each constant has an `AI_WALLPAPERS_*` environment
override. Repository-relative defaults resolve through the containing
workspace; production values belong only in the untracked owner-readable
configuration file.
