# Producer pipeline

`pipeline.zsh` handles the deterministic parts of the daily release workflow.
The Codex automation remains responsible for the work that needs judgment:

- inspecting the reference images and choosing the next visual direction;
- generating and visually reviewing the triptych;
- writing the one-sentence story;
- searching Spotify and choosing an appropriate existing public playlist.

Everything else is exposed as small, idempotent commands:

```sh
producer/pipeline.zsh preflight
producer/pipeline.zsh references
producer/pipeline.zsh validate-native
producer/pipeline.zsh upscale
producer/pipeline.zsh inspect-playlist /path/to/spotify-candidate.json
producer/pipeline.zsh validate-playlist /path/to/spotify-candidate.json
producer/pipeline.zsh stage
producer/pipeline.zsh publish
producer/pipeline.zsh replace-release-assets
```

## Reference roles

`references` returns two deliberately separate groups:

- `style_references` comes only from
  `/Users/ianmatson/Documents/Backgrounds/Story/style-references`. These files
  are the exclusive source of rendering style, shape language, palette
  handling, and texture.
- `historical_context` comes only from prior native story frames. Codex reviews
  these for narrative and continuity context, translates that context into
  words, and never passes the historical image files to the image generator.

This boundary prevents rendering artifacts or incidental style drift in prior
generations from becoming self-reinforcing.

Run `producer/pipeline.zsh context` for the current tag and exact archive paths.
The automation writes its selected playlist candidate to a new temporary JSON
file and its story sentence to the returned `story_file` path. The playlist
validator rejects duplicate or publicly unresolvable playlists before it
creates the accepted `spotify-playlist.json`. Generative-search results are
allowed when their exact public page and Spotify oEmbed metadata both validate.
`inspect-playlist` also returns Spotify's public playlist description so Codex
can judge specificity and ambiance rather than relying on a generic title.

An explicit soundtrack reroll is append-only:

```sh
producer/pipeline.zsh replace-playlist /path/to/better-candidate.json
producer/pipeline.zsh stage
producer/pipeline.zsh publish
```

That creates numbered `spotify-playlist-rN.json` and `release-notes-rN.txt`
revisions. Prior choices and notes remain untouched while the release body is
updated to the newest validated revision.

The script never overwrites an existing native, upscaled, or staged artifact.
On a rerun it validates and reuses good artifacts, and stops on a conflict.
`publish` also validates the release assets, embedded image previews, public
Spotify page and oEmbed metadata before applying the 30-release retention rule.

When a published day's imagery must be corrected, archive the correction under
new local revision roots, stage it there, and run
`producer/pipeline.zsh replace-release-assets`. The command requires an existing
release with exactly the three expected assets, replaces only those assets with
the validated staged files, updates the notes, and revalidates the release.

For safe isolated tests, each constant has an `AI_WALLPAPERS_*` environment
override. Production uses the defaults embedded in the script.
