#!/bin/zsh

set -euo pipefail
umask 022

readonly TIME_ZONE="${AI_WALLPAPERS_TIME_ZONE:-America/Chicago}"
readonly REPOSITORY="${AI_WALLPAPERS_REPOSITORY:-/Users/ianmatson/Repositories/ai-wallpapers}"
readonly REQUIRED_ORIGIN="${AI_WALLPAPERS_REQUIRED_ORIGIN:-git@github.com:ianmatson/ai-wallpapers.git}"
readonly GITHUB_REPOSITORY="${AI_WALLPAPERS_GITHUB_REPOSITORY:-ianmatson/ai-wallpapers}"
readonly NATIVE_ROOT="${AI_WALLPAPERS_NATIVE_ROOT:-/Users/ianmatson/Documents/Backgrounds/Story/native}"
readonly UPSCALED_ROOT="${AI_WALLPAPERS_UPSCALED_ROOT:-/Users/ianmatson/Documents/Backgrounds/Story/upscaled}"
readonly STAGING_ROOT="${AI_WALLPAPERS_STAGING_ROOT:-/Users/ianmatson/Documents/Backgrounds/Story/staging}"
readonly UPSCAYL_INBOX="${AI_WALLPAPERS_UPSCAYL_INBOX:-/Users/ianmatson/Documents/Codex/Upscayl/inbox}"
readonly UPSCAYL_OUTPUT="${AI_WALLPAPERS_UPSCAYL_OUTPUT:-/Users/ianmatson/Documents/Backgrounds/Upscaled}"
readonly SEED_IMAGE="${AI_WALLPAPERS_SEED_IMAGE:-/Users/ianmatson/Documents/Backgrounds/digital-alpine-observatory.png}"
readonly UPSCALE_TIMEOUT_SECONDS="${AI_WALLPAPERS_UPSCALE_TIMEOUT_SECONDS:-2700}"

readonly RUN_DATE="${AI_WALLPAPERS_RUN_DATE:-$(TZ="$TIME_ZONE" date +%F)}"
readonly TAG="wall-$RUN_DATE"
readonly NATIVE_DIR="$NATIVE_ROOT/$TAG"
readonly UPSCALED_DIR="$UPSCALED_ROOT/$TAG"
readonly STAGING_DIR="$STAGING_ROOT/$TAG"
readonly SPOTIFY_ACCEPTED="$STAGING_DIR/spotify-playlist.json"
readonly STORY_FILE="$STAGING_DIR/story.txt"
readonly NOTES_FILE="$STAGING_DIR/release-notes.txt"
readonly SLOTS=(left middle right)

die() {
  print -u2 -r -- "ERROR: $*"
  exit 1
}

info() {
  print -u2 -r -- "[$(TZ="$TIME_ZONE" date '+%F %T %Z')] $*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

require_file() {
  [[ -f "$1" ]] || die "required file is missing: $1"
}

image_info() {
  local image="$1"
  local details width height format

  require_file "$image"
  details="$(sips -g pixelWidth -g pixelHeight -g format "$image" 2>/dev/null)" || die "unreadable image: $image"
  width="$(awk '/pixelWidth:/ { print $2 }' <<<"$details")"
  height="$(awk '/pixelHeight:/ { print $2 }' <<<"$details")"
  format="$(awk '/format:/ { print tolower($2) }' <<<"$details")"
  [[ "$width" == <-> && "$height" == <-> ]] || die "could not read image dimensions: $image"
  print -r -- "$width $height $format"
}

require_png() {
  local image="$1" expected_width="${2:-}" expected_height="${3:-}"
  local width height format
  read -r width height format <<<"$(image_info "$image")"
  [[ "$format" == "png" ]] || die "expected PNG, got $format: $image"
  [[ -z "$expected_width" || "$width" == "$expected_width" ]] || die "unexpected width for $image: $width (expected $expected_width)"
  [[ -z "$expected_height" || "$height" == "$expected_height" ]] || die "unexpected height for $image: $height (expected $expected_height)"
  print -r -- "$width $height"
}

require_jpeg() {
  local image="$1" expected_width="$2" expected_height="$3"
  local width height format
  read -r width height format <<<"$(image_info "$image")"
  [[ "$format" == "jpeg" ]] || die "expected JPEG, got $format: $image"
  [[ "$width" == "$expected_width" && "$height" == "$expected_height" ]] || \
    die "unexpected dimensions for $image: ${width}x${height} (expected ${expected_width}x${expected_height})"
}

context() {
  jq -n \
    --arg run_date "$RUN_DATE" \
    --arg tag "$TAG" \
    --arg native_dir "$NATIVE_DIR" \
    --arg upscaled_dir "$UPSCALED_DIR" \
    --arg staging_dir "$STAGING_DIR" \
    --arg spotify_accepted "$SPOTIFY_ACCEPTED" \
    --arg story_file "$STORY_FILE" \
    --arg notes_file "$NOTES_FILE" \
    '{run_date:$run_date,tag:$tag,native_dir:$native_dir,upscaled_dir:$upscaled_dir,staging_dir:$staging_dir,spotify_accepted:$spotify_accepted,story_file:$story_file,notes_file:$notes_file}'
}

preflight() {
  require_command git
  require_command gh
  require_command jq
  require_command curl
  require_command sips

  [[ -d "$REPOSITORY/.git" ]] || die "repository is missing .git: $REPOSITORY"
  [[ "$(git -C "$REPOSITORY" branch --show-current)" == "main" ]] || die "repository branch is not main"
  [[ -z "$(git -C "$REPOSITORY" status --porcelain)" ]] || die "repository worktree is not clean"
  [[ "$(git -C "$REPOSITORY" remote get-url origin)" == "$REQUIRED_ORIGIN" ]] || die "repository origin does not equal $REQUIRED_ORIGIN"

  local login
  if ! login="$(gh api user --jq .login 2>&1)"; then
    if [[ "$login" == *"Could not resolve host"* || "$login" == *"connection"* || "$login" == *"network"* ]]; then
      die "network access to api.github.com failed: $login"
    fi
    die "gh api user failed: $login"
  fi
  [[ "$login" == "ianmatson" ]] || die "unexpected GitHub account: $login"
  gh auth status -h github.com >/dev/null || die "gh auth status failed"

  git -C "$REPOSITORY" fetch --prune origin
  git -C "$REPOSITORY" pull --ff-only origin main
  require_file "$REPOSITORY/README.md"
  info "preflight passed; README contract still requires agent review"
}

references() {
  local candidate primary_dir="" primary_kind="" legacy=""
  local -a complete_dirs primary_files older_files

  [[ -d "$NATIVE_ROOT" ]] || mkdir -p "$NATIVE_ROOT"

  while IFS= read -r candidate; do
    local directory="${candidate:h}"
    [[ "$directory" == "$NATIVE_DIR" ]] && continue
    if [[ -f "$directory/landscape-middle.png" && -f "$directory/landscape-right.png" ]]; then
      complete_dirs+=("$directory")
    fi
  done < <(find "$NATIVE_ROOT" -type f -name landscape-left.png -print | LC_ALL=C sort -r)

  if (( ${#complete_dirs[@]} > 0 )); then
    primary_dir="${complete_dirs[1]}"
    primary_kind="triptych"
    primary_files=(
      "$primary_dir/landscape-left.png"
      "$primary_dir/landscape-middle.png"
      "$primary_dir/landscape-right.png"
    )
    for candidate in "${complete_dirs[@]:1:2}"; do
      older_files+=("$candidate/landscape-middle.png")
    done
  else
    local newest_epoch=0 epoch image
    while IFS= read -r image; do
      [[ "$image" == "$NATIVE_DIR"/* ]] && continue
      epoch="$(stat -f %m "$image")"
      if (( epoch > newest_epoch )); then
        newest_epoch="$epoch"
        legacy="$image"
      fi
    done < <(find "$NATIVE_ROOT" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print)

    if [[ -n "$legacy" ]]; then
      primary_kind="legacy"
      primary_files=("$legacy")
    else
      require_file "$SEED_IMAGE"
      primary_kind="seed"
      primary_files=("$SEED_IMAGE")
    fi
  fi

  local primary_json older_json
  primary_json="$(printf '%s\n' "${primary_files[@]}" | jq -R . | jq -s .)"
  if (( ${#older_files[@]} > 0 )); then
    older_json="$(printf '%s\n' "${older_files[@]}" | jq -R . | jq -s .)"
  else
    older_json='[]'
  fi

  jq -n \
    --arg kind "$primary_kind" \
    --argjson primary "$primary_json" \
    --argjson older "$older_json" \
    '{primary_kind:$kind,primary:$primary,older_style_references:$older}'
}

validate_native() {
  local first_width="" first_height="" slot width height
  [[ -d "$NATIVE_DIR" ]] || die "native directory is missing: $NATIVE_DIR"

  for slot in "${SLOTS[@]}"; do
    read -r width height <<<"$(require_png "$NATIVE_DIR/landscape-$slot.png")"
    (( width > height )) || die "native image is not landscape: $NATIVE_DIR/landscape-$slot.png"
    if [[ -z "$first_width" ]]; then
      first_width="$width"
      first_height="$height"
    elif [[ "$width" != "$first_width" || "$height" != "$first_height" ]]; then
      die "native triptych dimensions do not match"
    fi
  done

  jq -n --arg directory "$NATIVE_DIR" --argjson width "$first_width" --argjson height "$first_height" \
    '{directory:$directory,width:$width,height:$height,files:["landscape-left.png","landscape-middle.png","landscape-right.png"]}'
}

upscale() {
  validate_native >/dev/null
  mkdir -p "$UPSCAYL_INBOX"

  local slot native queued result archived width height expected_width expected_height now
  local deadline=$(( $(date +%s) + UPSCALE_TIMEOUT_SECONDS ))

  for slot in "${SLOTS[@]}"; do
    native="$NATIVE_DIR/landscape-$slot.png"
    queued="$UPSCAYL_INBOX/$TAG-landscape-$slot.png"
    result="$UPSCAYL_OUTPUT/$TAG-landscape-$slot-4x.png"
    archived="$UPSCALED_DIR/landscape-$slot.png"
    read -r width height <<<"$(require_png "$native")"
    expected_width=$(( width * 4 ))
    expected_height=$(( height * 4 ))

    if [[ -e "$archived" ]]; then
      require_png "$archived" "$expected_width" "$expected_height" >/dev/null
      info "reusing archived upscale: $archived"
      continue
    fi

    if [[ -e "$result" ]]; then
      require_png "$result" "$expected_width" "$expected_height" >/dev/null
      info "reusing completed Upscayl result: $result"
      continue
    fi

    if [[ -e "$queued" ]]; then
      require_png "$queued" "$width" "$height" >/dev/null
      info "already queued: $queued"
    else
      cp -p "$native" "$queued"
      info "queued: $queued"
    fi
  done

  for slot in "${SLOTS[@]}"; do
    native="$NATIVE_DIR/landscape-$slot.png"
    result="$UPSCAYL_OUTPUT/$TAG-landscape-$slot-4x.png"
    archived="$UPSCALED_DIR/landscape-$slot.png"
    [[ -e "$archived" ]] && continue
    read -r width height <<<"$(require_png "$native")"
    expected_width=$(( width * 4 ))
    expected_height=$(( height * 4 ))

    while true; do
      if [[ -f "$result" ]] && require_png "$result" "$expected_width" "$expected_height" >/dev/null 2>&1; then
        break
      fi
      now="$(date +%s)"
      (( now < deadline )) || break
      sleep 5
    done
    [[ -f "$result" ]] || die "timed out waiting for Upscayl result: $result"
    require_png "$result" "$expected_width" "$expected_height" >/dev/null
  done

  mkdir -p "$UPSCALED_DIR"
  for slot in "${SLOTS[@]}"; do
    native="$NATIVE_DIR/landscape-$slot.png"
    result="$UPSCAYL_OUTPUT/$TAG-landscape-$slot-4x.png"
    archived="$UPSCALED_DIR/landscape-$slot.png"
    read -r width height <<<"$(require_png "$native")"
    expected_width=$(( width * 4 ))
    expected_height=$(( height * 4 ))
    if [[ -e "$archived" ]]; then
      require_png "$archived" "$expected_width" "$expected_height" >/dev/null
    else
      cp -p "$result" "$archived"
      require_png "$archived" "$expected_width" "$expected_height" >/dev/null
    fi
  done

  jq -n --arg directory "$UPSCALED_DIR" '{directory:$directory,files:["landscape-left.png","landscape-middle.png","landscape-right.png"]}'
}

public_validate_spotify() {
  local json_file="$1"
  local title creator type uri url playable gs_hint subtitle_type
  local page_status oembed_status oembed_tmp oembed_title oembed_provider

  require_file "$json_file"
  jq -e 'type == "object"' "$json_file" >/dev/null || die "Spotify candidate is not a JSON object: $json_file"
  title="$(jq -er '.title | select(type == "string" and length > 0)' "$json_file")" || die "Spotify candidate lacks title"
  creator="$(jq -er '.creator | select(type == "string" and length > 0)' "$json_file")" || die "Spotify candidate lacks creator"
  type="$(jq -er '.type' "$json_file")" || die "Spotify candidate lacks type"
  uri="$(jq -er '.uri' "$json_file")" || die "Spotify candidate lacks URI"
  url="$(jq -er '.url' "$json_file")" || die "Spotify candidate lacks URL"
  playable="$(jq -er '.playable_status' "$json_file")" || die "Spotify candidate lacks playback status"
  gs_hint="$(jq -r '.gs_hint // false' "$json_file")"
  subtitle_type="$(jq -r '.subtitle_type // .playlist_subtitle_metadata.type // ""' "$json_file")"

  [[ "$type" == "playlist" ]] || die "Spotify result type is not playlist: $type"
  [[ "$playable" == "PLAYABLE" ]] || die "Spotify result is not PLAYABLE: $playable"
  [[ "$uri" == spotify:playlist:* ]] || die "invalid Spotify playlist URI: $uri"
  [[ "$url" == https://open.spotify.com/playlist/* ]] || die "invalid Spotify playlist URL: $url"
  [[ "$gs_hint" != "true" ]] || die "generative Spotify result rejected: $title"
  [[ "$subtitle_type" != "GENERATIVE" && "$subtitle_type" != "MADE_FOR_YOU" ]] || die "non-public Spotify result rejected: $subtitle_type"

  page_status="$(curl -L -sS -o /dev/null -w '%{http_code}' "$url")" || die "Spotify playlist page request failed: $url"
  [[ "$page_status" == "200" ]] || die "Spotify playlist page returned HTTP $page_status: $url"

  oembed_tmp="$(mktemp -t ai-wallpapers-spotify-oembed.XXXXXX)"
  oembed_status="$(curl -G -sS -o "$oembed_tmp" -w '%{http_code}' --data-urlencode "url=$url" https://open.spotify.com/oembed)" || {
    rm -f "$oembed_tmp"
    die "Spotify oEmbed request failed: $url"
  }
  [[ "$oembed_status" == "200" ]] || {
    rm -f "$oembed_tmp"
    die "Spotify oEmbed returned HTTP $oembed_status: $url"
  }
  oembed_title="$(jq -er '.title' "$oembed_tmp")" || {
    rm -f "$oembed_tmp"
    die "Spotify oEmbed response lacks a title"
  }
  oembed_provider="$(jq -er '.provider_name' "$oembed_tmp")" || {
    rm -f "$oembed_tmp"
    die "Spotify oEmbed response lacks a provider"
  }
  rm -f "$oembed_tmp"

  [[ "$oembed_title" == "$title" ]] || die "Spotify oEmbed title mismatch: '$oembed_title' != '$title'"
  [[ "$oembed_provider" == "Spotify" ]] || die "Spotify oEmbed provider mismatch: $oembed_provider"

  SPOTIFY_PAGE_STATUS="$page_status"
  SPOTIFY_OEMBED_STATUS="$oembed_status"
  SPOTIFY_OEMBED_TITLE="$oembed_title"
  SPOTIFY_OEMBED_PROVIDER="$oembed_provider"
}

validate_playlist() {
  local candidate="${1:-}"
  local uri url existing releases_tmp enhanced_tmp

  if [[ -f "$SPOTIFY_ACCEPTED" ]]; then
    public_validate_spotify "$SPOTIFY_ACCEPTED"
    info "reusing validated Spotify playlist: $(jq -r .title "$SPOTIFY_ACCEPTED")"
    print -r -- "$SPOTIFY_ACCEPTED"
    return
  fi

  [[ -n "$candidate" ]] || die "usage: pipeline.zsh validate-playlist CANDIDATE_JSON"
  require_file "$candidate"
  public_validate_spotify "$candidate"
  uri="$(jq -r .uri "$candidate")"
  url="$(jq -r .url "$candidate")"

  while IFS= read -r existing; do
    [[ "$existing" == "$SPOTIFY_ACCEPTED" ]] && continue
    if [[ "$(jq -r '.uri // ""' "$existing" 2>/dev/null)" == "$uri" ]]; then
      die "Spotify playlist URI already exists in local staging archive: $uri"
    fi
  done < <(find "$STAGING_ROOT" -type f -name spotify-playlist.json -print 2>/dev/null)

  releases_tmp="$(mktemp -t ai-wallpapers-releases.XXXXXX)"
  gh api "/repos/$GITHUB_REPOSITORY/releases?per_page=30" >"$releases_tmp"
  if jq -er --arg tag "$TAG" --arg url "$url" '[.[] | select(.tag_name != $tag) | (.body // "") | contains($url)] | any' "$releases_tmp" | grep -qx true; then
    rm -f "$releases_tmp"
    die "Spotify playlist URL already appears in a recent GitHub Release: $url"
  fi
  rm -f "$releases_tmp"

  mkdir -p "$STAGING_DIR"
  enhanced_tmp="$(mktemp -t ai-wallpapers-spotify-accepted.XXXXXX)"
  jq \
    --argjson page "$SPOTIFY_PAGE_STATUS" \
    --argjson oembed "$SPOTIFY_OEMBED_STATUS" \
    --arg oembed_title "$SPOTIFY_OEMBED_TITLE" \
    --arg oembed_provider "$SPOTIFY_OEMBED_PROVIDER" \
    '. + {page_http_status:$page,oembed_http_status:$oembed,oembed_title:$oembed_title,oembed_provider:$oembed_provider}' \
    "$candidate" >"$enhanced_tmp"
  mv "$enhanced_tmp" "$SPOTIFY_ACCEPTED"
  info "accepted Spotify playlist: $(jq -r .title "$SPOTIFY_ACCEPTED")"
  print -r -- "$SPOTIFY_ACCEPTED"
}

stage() {
  validate_native >/dev/null
  require_file "$SPOTIFY_ACCEPTED"
  public_validate_spotify "$SPOTIFY_ACCEPTED"
  require_file "$STORY_FILE"

  local story line_count slot png jpg width height expected_tmp
  story="$(<"$STORY_FILE")"
  line_count="$(awk 'NF { count++ } END { print count + 0 }' "$STORY_FILE")"
  [[ "$line_count" == "1" && -n "$story" ]] || die "story.txt must contain exactly one non-empty line"

  for slot in "${SLOTS[@]}"; do
    png="$UPSCALED_DIR/landscape-$slot.png"
    jpg="$STAGING_DIR/landscape-$slot.jpg"
    read -r width height <<<"$(require_png "$png")"
    if [[ -e "$jpg" ]]; then
      require_jpeg "$jpg" "$width" "$height"
    else
      mkdir -p "$STAGING_DIR"
      sips -s format jpeg -s formatOptions 95 "$png" --out "$jpg" >/dev/null
      require_jpeg "$jpg" "$width" "$height"
    fi
  done

  expected_tmp="$(mktemp -t ai-wallpapers-notes.XXXXXX)"
  {
    print -r -- "$story"
    print
    print -r -- "| Left | Middle | Right |"
    print -r -- "|:---:|:---:|:---:|"
    print -r -- "| ![Left panel](https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/landscape-left.jpg) | ![Middle panel](https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/landscape-middle.jpg) | ![Right panel](https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/landscape-right.jpg) |"
    print
    print -r -- "🎧 **Soundtrack:** [$(jq -r .title "$SPOTIFY_ACCEPTED")]($(jq -r .url "$SPOTIFY_ACCEPTED")) — $(jq -r .creator "$SPOTIFY_ACCEPTED")"
  } >"$expected_tmp"

  if [[ -e "$NOTES_FILE" ]]; then
    cmp -s "$expected_tmp" "$NOTES_FILE" || {
      rm -f "$expected_tmp"
      die "existing release notes differ from deterministic output: $NOTES_FILE"
    }
    rm -f "$expected_tmp"
  else
    mv "$expected_tmp" "$NOTES_FILE"
  fi

  jq -n --arg directory "$STAGING_DIR" --arg notes "$NOTES_FILE" \
    '{directory:$directory,notes:$notes,assets:["landscape-left.jpg","landscape-middle.jpg","landscape-right.jpg"]}'
}

validate_release() {
  require_file "$NOTES_FILE"
  require_file "$SPOTIFY_ACCEPTED"
  local release_json body latest slot asset_url spotify_url
  release_json="$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json url,tagName,assets,body)" || die "GitHub Release does not exist: $TAG"
  [[ "$(jq -r .tagName <<<"$release_json")" == "$TAG" ]] || die "release tag mismatch"
  jq -e '.assets | map(.name) | sort == ["landscape-left.jpg","landscape-middle.jpg","landscape-right.jpg"]' <<<"$release_json" >/dev/null || \
    die "release does not have exactly the three expected assets"

  latest="$(gh release view --repo "$GITHUB_REPOSITORY" --json tagName --jq .tagName)"
  [[ "$latest" == "$TAG" ]] || die "latest release is $latest, expected $TAG"
  body="$(jq -r .body <<<"$release_json")"
  spotify_url="$(jq -r .url "$SPOTIFY_ACCEPTED")"
  [[ "$body" == *"$spotify_url"* ]] || die "release body lacks exact Spotify URL"

  for slot in "${SLOTS[@]}"; do
    asset_url="https://github.com/$GITHUB_REPOSITORY/releases/download/$TAG/landscape-$slot.jpg"
    [[ "$body" == *"$asset_url"* ]] || die "release body lacks embedded asset URL: $asset_url"
    [[ "$(curl -L -sS -o /dev/null -w '%{http_code}' "$asset_url")" == "200" ]] || die "embedded asset URL does not resolve: $asset_url"
  done
  public_validate_spotify "$SPOTIFY_ACCEPTED"

  jq -n \
    --arg url "$(jq -r .url <<<"$release_json")" \
    --arg tag "$TAG" \
    --arg spotify_title "$(jq -r .title "$SPOTIFY_ACCEPTED")" \
    --arg spotify_url "$spotify_url" \
    '{url:$url,tag:$tag,assets:["landscape-left.jpg","landscape-middle.jpg","landscape-right.jpg"],embedded_previews:true,spotify:{title:$spotify_title,url:$spotify_url,publicly_validated:true}}'
}

retention() {
  local releases_json old_tag
  releases_json="$(gh release list --repo "$GITHUB_REPOSITORY" --limit 100 --exclude-drafts --exclude-pre-releases --json tagName,publishedAt)"
  while IFS= read -r old_tag; do
    [[ -n "$old_tag" ]] || continue
    info "deleting expired wallpaper release: $old_tag"
    gh release delete "$old_tag" --repo "$GITHUB_REPOSITORY" --cleanup-tag --yes
  done < <(jq -r '
    map(select(.tagName | test("^wall-[0-9]{4}-[0-9]{2}-[0-9]{2}$")))
    | sort_by(.publishedAt) | reverse | .[30:][]?.tagName
  ' <<<"$releases_json")
}

publish() {
  stage >/dev/null
  if gh release view "$TAG" --repo "$GITHUB_REPOSITORY" >/dev/null 2>&1; then
    local release_json
    release_json="$(gh release view "$TAG" --repo "$GITHUB_REPOSITORY" --json assets)"
    jq -e '.assets | map(.name) | sort == ["landscape-left.jpg","landscape-middle.jpg","landscape-right.jpg"]' <<<"$release_json" >/dev/null || \
      die "existing release assets are invalid; refusing to replace them"
    gh release edit "$TAG" --repo "$GITHUB_REPOSITORY" --notes-file "$NOTES_FILE" >/dev/null
  else
    gh release create "$TAG" \
      "$STAGING_DIR/landscape-left.jpg" \
      "$STAGING_DIR/landscape-middle.jpg" \
      "$STAGING_DIR/landscape-right.jpg" \
      --repo "$GITHUB_REPOSITORY" \
      --title "Wallpaper $RUN_DATE" \
      --notes-file "$NOTES_FILE" \
      --latest >/dev/null
  fi
  validate_release
  retention
}

usage() {
  cat <<'EOF'
Usage: producer/pipeline.zsh COMMAND [ARG]

Commands:
  context                         Print today's paths and tag as JSON.
  preflight                       Validate Git/GitHub state, fetch, and fast-forward pull.
  references                      Print the local reference-image manifest as JSON.
  validate-native                 Validate today's three native PNGs.
  upscale                         Queue, wait for, validate, and archive 4x PNGs.
  validate-playlist CANDIDATE     Publicly validate and accept a Spotify candidate JSON.
  stage                           Convert JPEGs and deterministically build release notes.
  publish                         Create/edit, validate, and apply 30-release retention.
  validate-release                Validate an already-published release without changing it.

Judgment remains outside this script: image concepts, archive visual review, image generation,
visual QA, story writing, Spotify search, and playlist selection.
EOF
}

main() {
  local command="${1:-}"
  shift || true
  case "$command" in
    context) context "$@" ;;
    preflight) preflight "$@" ;;
    references) references "$@" ;;
    validate-native) validate_native "$@" ;;
    upscale) upscale "$@" ;;
    validate-playlist) validate_playlist "$@" ;;
    stage) stage "$@" ;;
    publish) publish "$@" ;;
    validate-release) validate_release "$@" ;;
    -h|--help|help|"") usage ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
