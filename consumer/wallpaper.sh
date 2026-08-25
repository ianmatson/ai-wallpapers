#!/bin/zsh
# Wallpaper Journey subscriber for macOS. The default action downloads the latest
# triptych and applies it. --apply only reapplies the newest cached triptych, so
# the display watcher never needs network access. --check uninstalls everything
# if the user has set their own wallpaper, and --uninstall does so on demand.
# --status prints everything a bug report needs.

set -u

VERSION=2   # bump on any consumer change, and keep consumer/VERSION in the repo equal

# Don't inherit whatever PATH the caller had. Several steps here fail quietly
# when a tool is missing — a lost osascript reads as "no Spaces reference
# anything", which would let pruning delete an image a desktop is still using.
PATH="/usr/bin:/bin:/usr/sbin:/sbin"
export PATH

REPO="https://github.com/ianmatson/wallpaper-journey"
DIR="$HOME/WallpaperJourney"   # where images are saved — change this and both plist paths together
# Installs predating the rename kept their images here. The folder is left
# behind as a symlink so Spaces still pointing inside it keep rendering, which
# also means a path under it is ours, not a wallpaper the user chose.
LEGACY_DIR="$HOME/DailyWall"
KEEP=7                  # days of wallpapers to retain
CURRENT_TAG_FILE="$DIR/current-tag"
APPLIED_MARKER="$DIR/.applied"
RELOAD_MARKER="$DIR/.reloading"
NOTICE_MARKER="$DIR/.update-noticed"   # highest version already announced
QUIET_AFTER_RELOAD=30   # seconds to leave the restarting wallpaper agent alone
# Every Space stores its own wallpaper as a file path. Pointing them all at
# these three unchanging paths is what lets one morning download reach every
# desktop: the paths stay put and only the bytes behind them change.
STABLE_PREFIX="$DIR/current"
WALLPAPER_STORE="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
LOG_DIR="$HOME/Library/Logs/WallpaperJourney"   # where launchd sends both jobs' output
STABLE_CHANGED=0
CONVERGE_PENDING=0
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"
DAILY_JOB="com.ianmatson.wallpaper"
WATCHER_JOB="com.ianmatson.wallpaper-watcher"

mkdir -p "$DIR"

# Timestamped line for the launchd logs; a manual run shows it on the terminal.
note() {
  print -r -- "[$(date '+%F %T')] $*"
}

cached_tag() {
  local tag=""
  local slot
  local middle

  if [[ -r "$CURRENT_TAG_FILE" ]]; then
    tag="$(<"$CURRENT_TAG_FILE")"
  fi

  # Let existing subscribers upgrade without waiting for the next daily run.
  if [[ "$tag" != wall-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] ]]; then
    middle=$(print -rl -- "$DIR"/wall-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-landscape-middle.jpg(N) \
      | sort -r | head -n 1)
    [[ -n "$middle" ]] || return 1
    tag="${middle:t}"
    tag="${tag%-landscape-middle.jpg}"
  fi

  for slot in left middle right; do
    [[ -s "$DIR/$tag-landscape-$slot.jpg" ]] || return 1
  done

  print -r -- "$tag"
}

# Repoints the fixed wallpaper paths at a day's panels. Hard links, so the
# archive and the live wallpaper share one copy of each image on disk, and a
# pruned archive name never takes the bytes away from a Space still using them.
# Sets STABLE_CHANGED when anything moved.
publish_stable() {
  local tag="$1"
  local slot
  local src
  local dst
  local tmp

  STABLE_CHANGED=0
  for slot in left middle right; do
    src="$DIR/$tag-landscape-$slot.jpg"
    dst="$STABLE_PREFIX-$slot.jpg"
    [[ -s "$src" ]] || return 1
    [[ "$src" -ef "$dst" ]] && continue
    tmp="$dst.new.$$"
    ln -f -- "$src" "$tmp" 2>/dev/null || cp -f -- "$src" "$tmp" || { rm -f -- "$tmp"; return 1; }
    mv -f -- "$tmp" "$dst" || { rm -f -- "$tmp"; return 1; }
    STABLE_CHANGED=1
  done
  return 0
}

# Every question asked of the wallpaper store runs through this one JXA
# program, so the fragile part — decoding Apple's undocumented Index.plist,
# with image choices hidden in nested binary plists — lives in exactly one
# place. $1 selects the question:
#   status      ours / "theirs <unix-time>" / "theirs unknown" / nothing
#   referenced  paths under our folders that some desktop still points at
#   converge    rewrite the store so every desktop points at the fixed paths
#   describe    one readable line per display and Space, for --status
# The callers below document what each answer means.
store_query() {
  osascript -l JavaScript - "$1" "$WALLPAPER_STORE" "$DIR" "$LEGACY_DIR" "$STABLE_PREFIX" 2>/dev/null <<'EOF'
function run(argv) {
  ObjC.import("AppKit");
  const mode = argv[0];
  const storePath = argv[1];
  const dirs = [argv[2], argv[3]].map(function (d) { return d.replace(/\/*$/, "/"); });
  const stablePrefix = argv[4];

  // ---- shared decoding helpers ----

  function dict(value) {
    if (value === null || value === undefined) return null;
    return !value.isNil() && value.isKindOfClass($.NSDictionary) ? value : null;
  }

  function parsePlist(data, mutable) {
    if (data.isNil() || !data.isKindOfClass($.NSData)) return null;
    // 2 = mutable containers and leaves, so entries can be edited in place.
    const value = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(
      data, mutable ? 2 : 0, Ref(), Ref());
    return value.isNil() ? null : value;
  }

  function loadStore(mutable) {
    const store = parsePlist($.NSData.dataWithContentsOfFile(storePath), mutable);
    return store !== null && store.isKindOfClass($.NSDictionary) ? store : null;
  }

  function choiceOf(desktop) {
    if (desktop === null) return null;
    const content = dict(desktop.objectForKey("Content"));
    if (content === null) return null;
    const choices = content.objectForKey("Choices");
    if (choices.isNil() || !choices.isKindOfClass($.NSArray) || choices.count === 0) return null;
    const choice = choices.objectAtIndex(0);
    return choice.isKindOfClass($.NSDictionary) ? choice : null;
  }

  // The file path inside one Configuration blob, or null.
  function pathFromConfig(cfg) {
    const inner = parsePlist(cfg, false);
    if (inner === null || !inner.isKindOfClass($.NSDictionary)) return null;
    const url = dict(inner.objectForKey("url"));
    if (url === null) return null;
    const relative = ObjC.unwrap(url.objectForKey("relative"));
    if (!relative) return null;
    return ObjC.unwrap($.NSURL.URLWithString(relative).path);
  }

  function imagePath(desktop) {
    const choice = choiceOf(dict(desktop));
    if (choice === null) return null;
    if (ObjC.unwrap(choice.objectForKey("Provider")) !== "com.apple.wallpaper.choice.image") return null;
    return pathFromConfig(choice.objectForKey("Configuration"));
  }

  function ours(path) {
    return path !== null && dirs.some(function (d) { return path.startsWith(d); });
  }

  function lastSet(desktop) {
    const stamp = desktop.objectForKey("LastSet");
    return stamp.isNil() ? 0 : stamp.timeIntervalSince1970;
  }

  // ---- status ----

  // When was the wallpaper we are looking at chosen? A desktop showing an
  // image file answers exactly, by the path it recorded. A desktop showing one
  // of Apple's own wallpapers — dynamic, aerial, or a solid color — records no
  // file at all and so can never match a path, which is why the newest time on
  // any desktop that is not ours has to answer for it. Without that fallback
  // every such desktop reads as undatable, and an undatable desktop used to
  // end the subscription on sight.
  function chosenAt(store, wanted) {
    let exact = 0;
    let foreign = 0;
    function walk(value) {
      if (value.isNil()) return;
      if (value.isKindOfClass($.NSArray)) { value.js.forEach(walk); return; }
      if (!value.isKindOfClass($.NSDictionary)) return;
      const desktop = dict(value.objectForKey("Desktop"));
      if (desktop !== null) {
        const stamp = desktop.objectForKey("LastSet");
        if (!stamp.isNil()) {
          const path = imagePath(desktop);
          const when = stamp.timeIntervalSince1970;
          if (path === wanted) exact = Math.max(exact, when);
          else if (!ours(path)) foreign = Math.max(foreign, when);
        }
      }
      value.allValues.js.forEach(walk);
    }
    walk(store);
    return exact || foreign;
  }

  function statusMode() {
    const ws = $.NSWorkspace.sharedWorkspace;
    const screens = $.NSScreen.screens.js;
    if (screens.length === 0) return "";

    let foreignPath = null;
    for (const screen of screens) {
      const url = ws.desktopImageURLForScreen(screen);
      // No answer means unknown, not an opt-out: the wallpaper agent reports
      // nothing while it is busy, and guessing there would uninstall us.
      if (url.isNil()) return "";
      const path = ObjC.unwrap(url.path);
      if (!path) return "";
      if (!ours(path)) {
        foreignPath = path;
        break;
      }
    }
    if (foreignPath === null) return "ours";

    const store = loadStore(false);
    if (store === null) return "theirs unknown";
    const chosen = chosenAt(store, foreignPath);
    return chosen === 0 ? "theirs unknown" : "theirs " + Math.round(chosen);
  }

  // ---- referenced ----

  function referencedMode() {
    const store = loadStore(false);
    if (store === null) return "";
    const found = {};
    // Walk the whole store and decode any data blob that turns out to be an
    // image choice, whichever corner of the format it sits in.
    function walk(value) {
      if (value.isNil()) return;
      if (value.isKindOfClass($.NSDictionary)) {
        value.allValues.js.forEach(walk);
      } else if (value.isKindOfClass($.NSArray)) {
        value.js.forEach(walk);
      } else if (value.isKindOfClass($.NSData)) {
        const path = pathFromConfig(value);
        if (ours(path)) found[path] = true;
      }
    }
    walk(store);
    return Object.keys(found).join("\n");
  }

  // ---- converge ----

  function convergeMode() {
    function stablePath(slot) { return stablePrefix + "-" + slot + ".jpg"; }
    function slotOf(path) {
      if (/-left\.jpg$/.test(path)) return "left";
      if (/-right\.jpg$/.test(path)) return "right";
      return "middle";
    }

    const store = loadStore(true);
    if (store === null) return "";

    let changed = false;
    let pending = false;

    // Ours under a dated or pre-rename path is repointed at the fixed path for
    // its panel, so a stale entry can serve as a source like any other.
    function normalize(desktop) {
      const path = imagePath(desktop);
      if (!ours(path)) return;
      const slot = slotOf(path);
      if (path === stablePath(slot)) return;
      const choice = choiceOf(desktop);
      const inner = parsePlist(choice.objectForKey("Configuration"), true);
      if (inner === null || !inner.isKindOfClass($.NSDictionary)) return;
      const url = dict(inner.objectForKey("url"));
      if (url === null) return;
      url.setObjectForKey(
        ObjC.unwrap($.NSURL.fileURLWithPath(stablePath(slot)).absoluteString), "relative");
      // 200 = binary plist, the format the agent writes itself.
      const rewritten = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
        inner, 200, 0, Ref());
      if (rewritten.isNil()) return;
      choice.setObjectForKey(rewritten, "Configuration");
      changed = true;
    }

    // Deep, independent copy, via the same serializer that writes the file.
    function duplicate(desktop) {
      const blob = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
        desktop, 200, 0, Ref());
      if (blob.isNil()) return null;
      const copy = $.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(
        blob, 2, Ref(), Ref());
      return copy.isNil() ? null : copy;
    }

    const displays = dict(store.objectForKey("Displays"));
    if (displays === null) return "";
    const spaces = dict(store.objectForKey("Spaces"));

    // Everything on one display converges to one entry, so gather each
    // display's holders first: its own entry, plus each of its Spaces'
    // per-display entry and Default twin.
    const byDisplay = {};
    function holdersFor(key) {
      return byDisplay[key] || (byDisplay[key] = []);
    }
    displays.allKeys.js.forEach(function (dkey) {
      const entry = dict(displays.objectForKey(dkey));
      if (entry !== null) holdersFor(ObjC.unwrap(dkey)).push(entry);
    });
    if (spaces !== null) {
      spaces.allKeys.js.forEach(function (skey) {
        const space = dict(spaces.objectForKey(skey));
        if (space === null) return;
        const perDisplay = dict(space.objectForKey("Displays"));
        if (perDisplay === null) return;
        const def = dict(space.objectForKey("Default"));
        perDisplay.allKeys.js.forEach(function (dkey) {
          const holder = dict(perDisplay.objectForKey(dkey));
          if (holder === null) return;
          holdersFor(ObjC.unwrap(dkey)).push(holder);
          if (def !== null) holdersFor(ObjC.unwrap(dkey)).push(def);
        });
      });
    }

    Object.keys(byDisplay).forEach(function (dkey) {
      const holders = byDisplay[dkey];

      // The freshest ours entry on the display is the model everything else
      // copies. Newest wins because apply_tag's write is always the newest —
      // right after an install that is the Space it just set, since a
      // wallpaper the user set by hand lands on the display's own entry.
      let model = null;
      let modelStamp = -1;
      let foreign = false;
      holders.forEach(function (holder) {
        const desktop = dict(holder.objectForKey("Desktop"));
        if (desktop === null) return;
        if (!ours(imagePath(desktop))) {
          foreign = true;
          return;
        }
        if (lastSet(desktop) > modelStamp) {
          modelStamp = lastSet(desktop);
          model = desktop;
        }
      });
      if (model === null) {
        if (foreign) pending = true;
        return;
      }
      normalize(model);
      const modelPath = imagePath(model);

      holders.forEach(function (holder) {
        const desktop = holder.objectForKey("Desktop");
        if (!desktop.isNil() && imagePath(desktop) === modelPath) return;
        const copy = duplicate(model);
        if (copy === null) return;
        holder.setObjectForKey(copy, "Desktop");
        changed = true;
      });
    });

    if (changed) {
      const outData = $.NSPropertyListSerialization.dataWithPropertyListFormatOptionsError(
        store, 200, 0, Ref());
      if (outData.isNil() || !outData.writeToFileAtomically(storePath, true)) changed = false;
    }
    return (changed ? "changed " : "") + (pending ? "pending" : "");
  }

  // ---- describe ----

  function describeMode() {
    const store = loadStore(false);
    if (store === null) return "store unreadable";
    const lines = [];
    function shown(desktop) {
      const choice = choiceOf(dict(desktop));
      if (choice === null) return "none";
      const path = imagePath(desktop);
      return path !== null ? path : ObjC.unwrap(choice.objectForKey("Provider"));
    }
    const displays = dict(store.objectForKey("Displays"));
    if (displays !== null) {
      displays.allKeys.js.forEach(function (dkey) {
        const entry = dict(displays.objectForKey(dkey));
        if (entry === null) return;
        lines.push("display " + ObjC.unwrap(dkey).slice(0, 8) + "  " +
          shown(entry.objectForKey("Desktop")));
      });
    }
    const spaces = dict(store.objectForKey("Spaces"));
    if (spaces !== null) {
      spaces.allKeys.js.forEach(function (skey) {
        const space = dict(spaces.objectForKey(skey));
        if (space === null) return;
        const def = dict(space.objectForKey("Default"));
        lines.push("space   " + (ObjC.unwrap(skey) || "default*").slice(0, 8) + "  " +
          (def === null ? "none" : shown(def.objectForKey("Desktop"))));
      });
    }
    return lines.sort().join("\n");
  }

  if (mode === "status") return statusMode();
  if (mode === "referenced") return referencedMode();
  if (mode === "converge") return convergeMode();
  if (mode === "describe") return describeMode();
  return "";
}
EOF
}

# The store is the wallpaper agent's memory of every desktop, on screen or not.
# Editing it is the only way to reach a Space that is not visible: the public
# API stops at the active Space of each display, and Apple ships nothing else.
# So converge the whole store in one pass: for each display, take the entry of
# ours the agent stamped most recently — apply_tag's write is always the
# newest — and copy it over every entry on that display that differs, Spaces
# and the display's own entry alike. That converts a desktop showing something
# foreign, repoints a dated or pre-rename path at the fixed paths, corrects a
# Space carrying the wrong panel for its display, and gives new Spaces an ours
# entry to inherit. The agent reload that follows lands it all on screen.
#
# The source entry can as easily be a Space as the display's own entry: macOS
# stamps a wallpaper set by hand onto the display entry itself, so right after
# an install the freshest ours entry on a display is usually the Space
# apply_tag just set, not the display.
#
# Copy, never invent: every entry written here is a byte copy of one the agent
# already accepted. Anything unrecognized — an unreadable store, a reshaped
# format — is left alone, and the cost of that caution is only that those
# desktops keep their old wallpaper. Sets STABLE_CHANGED when the store moved
# and a reload is owed, and CONVERGE_PENDING when a display had foreign entries
# but nothing of ours to copy yet — the agent records what apply_tag set only a
# few seconds after the fact, so pending resolves by waiting and trying again.
converge_store() {
  local out

  CONVERGE_PENDING=0
  out=$(store_query converge)
  [[ "$out" == *changed* ]] && STABLE_CHANGED=1
  [[ "$out" == *pending* ]] && CONVERGE_PENDING=1
  return 0
}

# Restarting the wallpaper agent makes it reload every Space from disk. Because
# each Space points at a path whose bytes we just replaced, they all come back
# showing today's image — no per-Space API, and the agent's own store is never
# written to. SIP blocks launchctl kickstart for this service, so signal it.
#
# The marker dates the restart. Until the agent has read its store back it
# answers with whatever it likes, and the watcher must not read one of those
# answers as the user choosing a wallpaper.
reload_all_spaces() {
  : > "$RELOAD_MARKER"
  killall WallpaperAgent 2>/dev/null || true
}

# True while the wallpaper agent is still coming back from our own reload.
reloading() {
  local stamp

  stamp=$(stat -f %m "$RELOAD_MARKER" 2>/dev/null) || return 1
  (( $(date +%s) - stamp < QUIET_AFTER_RELOAD ))
}

apply_tag() {
  local tag="$1"
  local count
  local slot
  local i
  local -a slots
  local -a rotation
  local -a files

  # One image slot per connected display: 1 monitor gets middle, 2 get the
  # adjacent left+middle pair, 3 get all three, more than 3 cycle again.
  count=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSScreen.screens.count' 2>/dev/null)
  (( count >= 1 )) || count=1
  case $count in
    1) slots=(middle) ;;
    2) slots=(left middle) ;;   # adjacent panels, so the pair stays continuous
    *) rotation=(left middle right)
       slots=()
       for ((i = 0; i < count; i++)); do
         slots+=("${rotation[$((i % 3 + 1))]}")
       done ;;
  esac

  # Upgrades from a version that pointed Spaces at dated filenames land here
  # with no fixed paths yet.
  [[ -s "$STABLE_PREFIX-middle.jpg" ]] || publish_stable "$tag" || return 1

  files=()
  for slot in "${slots[@]}"; do
    [[ -s "$STABLE_PREFIX-$slot.jpg" ]] || return 1
    files+=("$STABLE_PREFIX-$slot.jpg")
  done

  # Set one image per screen, leftmost first. Keeps each screen's scaling mode.
  osascript -l JavaScript - "${files[@]}" <<'EOF'
function run(argv) {
  ObjC.import("AppKit");
  const ws = $.NSWorkspace.sharedWorkspace;
  const screens = $.NSScreen.screens.js.sort((a, b) => {
    const horizontal = a.frame.origin.x - b.frame.origin.x;
    return horizontal || b.frame.origin.y - a.frame.origin.y;
  });
  screens.forEach((screen, index) => {
    const url = $.NSURL.fileURLWithPath(argv[index % argv.length]);
    ws.setDesktopImageURLForScreenOptionsError(
      url,
      screen,
      ws.desktopImageOptionsForScreen(screen),
      $()
    );
  });
}
EOF
  # The marker records that this machine has shown a Wallpaper Journey
  # wallpaper, so a pre-install desktop never reads as the user opting back out.
  [[ $? -eq 0 ]] && : > "$APPLIED_MARKER"
}

# Prints "ours" when every screen's wallpaper lives in $DIR or the folder used
# before the rename, "theirs <unix-time>" when any screen shows something else,
# "theirs unknown" when it does but the store cannot date it, and nothing when
# the answer is unknowable. The time says when that wallpaper was chosen, which
# is what separates a desktop this subscription has never reached from one the
# user has just changed.
wallpaper_status() {
  store_query status
}

# Where the subscription stands on the desktops currently on screen:
#   optout   the user chose a wallpaper after our most recent apply
#   ok       every screen is ours, or shows a desktop we have never reached
#   unknown  a screen is not ours and nothing on hand says when it was chosen
subscription_state() {
  local state          # not "status": zsh keeps that one read-only
  local chosen
  local applied

  # Before the first apply there is nothing to opt out of.
  [[ -e "$APPLIED_MARKER" ]] || { print -r -- ok; return; }

  # None of the agent's answers count while it restarts from our own reload.
  reloading && { print -r -- unknown; return; }

  state="$(wallpaper_status)"
  case "$state" in
    ours) print -r -- ok; return ;;
    'theirs '*) ;;
    # No answer at all. Ask again on the next check.
    *) print -r -- unknown; return ;;
  esac

  chosen="${state#theirs }"
  # A store we could not read at all. A desktop we have never reached and one
  # the user has just changed look identical from here, so do neither thing
  # rather than guess: guessing once cost a subscriber the whole subscription.
  [[ "$chosen" == <-> ]] || { print -r -- unknown; return; }

  applied=$(stat -f %m "$APPLIED_MARKER" 2>/dev/null) || applied=0

  # A desktop this subscription has never reached still shows whatever the user
  # had before installing, and overwriting that on arrival is the job — ending
  # the subscription over it is not. Only a wallpaper chosen after our most
  # recent apply is a real opt-out.
  (( chosen > applied )) || { print -r -- ok; return; }

  # Confirm after a pause so our own apply, caught mid-flight with only some
  # screens set, never reads as a manual change.
  sleep 3
  case "$(wallpaper_status)" in
    'theirs '*) print -r -- optout ;;
    *) print -r -- ok ;;
  esac
}

# Removes everything the installer created. $1 is the launchd job the caller
# runs under; it is booted out last because bootout kills the job's processes,
# which would end this script before the cleanup finished.
uninstall() {
  local last="$1"
  local domain="gui/$(id -u)"
  local job

  for job in "$DAILY_JOB" "$WATCHER_JOB"; do
    [[ "$job" == "$last" ]] && continue
    launchctl bootout "$domain/$job" 2>/dev/null || true
  done

  # Delete only files Wallpaper Journey created, in case DIR points at a shared
  # folder.
  rm -f -- \
    "$LAUNCH_AGENTS/$DAILY_JOB.plist" \
    "$LAUNCH_AGENTS/$WATCHER_JOB.plist" \
    "$LOG_DIR/wallpaper.log" "$LOG_DIR/wallpaper-watcher.log" \
    /tmp/wallpaper.log /tmp/wallpaper-watcher.log \
    "$DIR"/wall-*(N) "$STABLE_PREFIX"-*.jpg(N) "$CURRENT_TAG_FILE" "$APPLIED_MARKER" \
    "$RELOAD_MARKER" "$NOTICE_MARKER" \
    "$DIR/wallpaper-watcher.js" "$DIR/wallpaper.sh"
  rmdir -- "$DIR" "$LOG_DIR" 2>/dev/null || true
  # The compatibility symlink left by the rename, but never a real folder that
  # happens to sit there.
  [[ -L "$LEGACY_DIR" ]] && rm -f -- "$LEGACY_DIR"

  launchctl bootout "$domain/$last" 2>/dev/null || true
}

self_destruct() {
  note "manual wallpaper change detected; uninstalling (from $1)"
  osascript -e 'display notification "You set your own wallpaper, so Wallpaper Journey uninstalled itself and removed its files." with title "Wallpaper Journey"' 2>/dev/null || true
  uninstall "$1"
}

# There is deliberately no auto-updater: subscribers run code from this repo
# once, at install, with consent — images are the only thing that flows after
# that, and a repo compromise must not become code running on their machines.
# So updates are announced, never applied: when the repo carries a newer
# consumer version, say so in one notification and let the user rerun the
# installer themselves. The marker keeps each version's announcement to one.
update_notice() {
  local remote
  local noticed=0
  local choice

  remote=$(curl -fsSL --max-time 10 \
    "https://raw.githubusercontent.com/ianmatson/wallpaper-journey/main/consumer/VERSION" \
    2>/dev/null) || return 0
  [[ "$remote" == <-> ]] || return 0
  (( remote > VERSION )) || return 0

  [[ -r "$NOTICE_MARKER" ]] && noticed="$(<"$NOTICE_MARKER")"
  [[ "$noticed" == <-> ]] || noticed=0
  (( remote > noticed )) || return 0

  note "consumer version $remote is available (this is $VERSION); announcing it"
  # The marker is written before the dialog so a version is announced at most
  # once, whatever happens to the dialog.
  print -r -- "$remote" > "$NOTICE_MARKER"

  # A macOS notification cannot carry a button, so ask with a dialog instead.
  # It dismisses itself, and "Later" simply means this version stays quiet —
  # the marker above already saw to that.
  choice=$(osascript -e 'display dialog "A new Wallpaper Journey version is available. Rerun the installer from the README to get it." with title "Wallpaper Journey" buttons {"Later", "Open the README"} default button "Open the README" giving up after 60' 2>/dev/null) || return 0
  if [[ "$choice" == *"button returned:Open the README"* && "$choice" != *"gave up:true"* ]]; then
    open "$REPO#updating--macos" 2>/dev/null || true
  fi
}

# Everything a bug report needs, in one paste.
show_status() {
  local domain="gui/$(id -u)"
  local job
  local when
  local state

  print -r -- "Wallpaper Journey consumer version $VERSION"
  for job in "$DAILY_JOB" "$WATCHER_JOB"; do
    if launchctl print "$domain/$job" >/dev/null 2>&1; then
      print -r -- "$job: loaded"
    else
      print -r -- "$job: not loaded"
    fi
  done
  if [[ -r "$CURRENT_TAG_FILE" ]]; then
    print -r -- "cached release: $(<"$CURRENT_TAG_FILE")"
  else
    print -r -- "cached release: none"
  fi
  if when=$(stat -f %Sm -t '%F %T' "$APPLIED_MARKER" 2>/dev/null); then
    print -r -- "last applied: $when"
  else
    print -r -- "last applied: never"
  fi
  state="$(wallpaper_status)"
  print -r -- "screens now: ${state:-unknown}"
  print -r -- "logs: $LOG_DIR"
  print -r -- "desktops (from the wallpaper store):"
  store_query describe | sed 's/^/  /'
}

# Paths under $DIR that the wallpaper agent still points a Space at. Read only;
# an unreadable or reshaped store just yields nothing and pruning carries on.
referenced_images() {
  store_query referenced
}

prune_cache() {
  local -a referenced
  local -a doomed
  local old
  local file

  referenced=(${(f)"$(referenced_images)"})
  doomed=(${(f)"$(print -rl -- "$DIR"/wall-*.jpg(N) \
    | sed -E 's|.*/(wall-[0-9]{4}-[0-9]{2}-[0-9]{2}).*|\1|' \
    | sort -ru | tail -n "+$((KEEP + 1))")"})

  for old in $doomed; do
    for file in "$DIR/$old"-*.jpg(N); do
      # A Space upgraded from an older version can still point at a dated name.
      # Dropping it would leave that desktop with no image at all.
      (( ${referenced[(I)$file]} )) && continue
      rm -f -- "$file"
    done
  done
}

refresh() {
  local tag
  local slot
  local out
  local tmp
  local tag_tmp
  local try

  # Resolve today's release tag from the /latest redirect (no API, no token).
  tag=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest") || return 0
  tag="${tag##*/}"
  [[ "$tag" == wall-* ]] || return 0

  # A desktop can be behind even when the release has not moved, so catch those
  # up before the early exit below rather than after it.
  if [[ -s "$STABLE_PREFIX-middle.jpg" ]]; then
    converge_store
    if (( STABLE_CHANGED )); then
      note "caught up desktops that were behind; reloading the wallpaper agent"
      reload_all_spaces
    fi
  fi

  # This runs several times a day so a late release still lands the same day.
  # Once the newest triptych is cached and on screen there is nothing to do,
  # and stopping here avoids re-setting a wallpaper that is already correct.
  if [[ -r "$CURRENT_TAG_FILE" && "$(<"$CURRENT_TAG_FILE")" == "$tag" ]] \
    && [[ -s "$STABLE_PREFIX-middle.jpg" ]] \
    && [[ "$(wallpaper_status)" == ours ]]; then
    return 0
  fi

  note "updating to $tag"

  # Cache the complete triptych. Display changes can then choose any layout
  # without downloading another asset.
  for slot in left middle right; do
    out="$DIR/$tag-landscape-$slot.jpg"
    [[ -s "$out" ]] && continue
    tmp="$out.download.$$"
    curl -fsSL -o "$tmp" "$REPO/releases/latest/download/landscape-$slot.jpg" \
      || { rm -f "$tmp"; note "download failed: landscape-$slot.jpg"; return 1; }
    [[ -s "$tmp" ]] || { rm -f "$tmp"; note "download empty: landscape-$slot.jpg"; return 1; }
    mv "$tmp" "$out"
  done

  # Publish the cache pointer only after all three panels are available.
  tag_tmp="$CURRENT_TAG_FILE.$$"
  print -r -- "$tag" > "$tag_tmp"
  mv "$tag_tmp" "$CURRENT_TAG_FILE"

  # Swap the bytes behind the fixed paths first, then set the visible desktops,
  # then converge the store so every other Space points at those paths too, then
  # make the agent reload. Order matters twice over: the new images must be in
  # place before anything points at them, and the converge must read the store
  # only after the agent has saved what apply_tag just set — it does so a few
  # seconds after a change, and converging a display needs an ours entry on it
  # to copy. Pending means that save has not landed yet, so wait and try again
  # rather than reloading a store that still has desktops to catch.
  publish_stable "$tag" || { note "publishing the fixed paths failed"; return 1 }
  apply_tag "$tag" || { note "applying to the visible displays failed"; return 1 }
  note "applied $tag to the visible displays"
  for try in 1 2 3 4 5; do
    sleep 5
    converge_store
    (( CONVERGE_PENDING )) || break
    note "converge pending (agent not settled yet), try $try of 5"
  done
  (( CONVERGE_PENDING )) && note "converge still pending; the next poll retries"
  if (( STABLE_CHANGED )); then
    note "reloading the wallpaper agent so every desktop picks up $tag"
    reload_all_spaces
  fi
  prune_cache
}

case "${1:-refresh}" in
  refresh|--refresh)
    case "$(subscription_state)" in
      optout) self_destruct "$DAILY_JOB" ;;
      ok) refresh; update_notice ;;
    esac
    ;;
  apply|--apply)
    tag=$(cached_tag) || exit 0
    note "display change: reapplying cached $tag"
    apply_tag "$tag"
    ;;
  status|--status)
    show_status
    ;;
  check|--check)
    if [[ "$(subscription_state)" == optout ]]; then
      self_destruct "$WATCHER_JOB"
    fi
    ;;
  uninstall|--uninstall)
    print -r -- "Removing Wallpaper Journey's launch agents, scripts, images, and logs."
    uninstall "$WATCHER_JOB"
    ;;
  *)
    print -u2 -- "usage: $0 [--refresh|--apply|--check|--status|--uninstall]"
    exit 2
    ;;
esac
