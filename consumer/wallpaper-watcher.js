#!/usr/bin/osascript -l JavaScript

ObjC.import("AppKit");
ObjC.import("Foundation");

// The wallpaper agent rewrites this file whenever any wallpaper changes, on any
// Space, so its timestamp is the signal that the user has chosen their own.
const STORE_PATH = ObjC.unwrap($.NSHomeDirectory()) +
  "/Library/Application Support/com.apple.wallpaper/Store/Index.plist";

let wallpaperScript = "";
let delegate = null;
let applyTimer = null;
let checkTimer = null;
let lastStoreStamp = 0;

function runWallpaperScript(action) {
  const task = $.NSTask.alloc.init;
  task.launchPath = "/bin/zsh";
  task.arguments = [wallpaperScript, action];
  task.launch;
}

function storeStamp() {
  const attributes = $.NSFileManager.defaultManager
    .attributesOfItemAtPathError(STORE_PATH, Ref());
  if (attributes.isNil()) return 0;
  const modified = attributes.objectForKey("NSFileModificationDate");
  if (modified.isNil()) return 0;
  return modified.timeIntervalSince1970;
}

function scheduleOnce(timer, delay, selector) {
  if (timer !== null) {
    timer.invalidate;
  }
  return $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    delay,
    delegate,
    selector,
    null,
    false
  );
}

function scheduleApply(delay) {
  applyTimer = scheduleOnce(applyTimer, delay, "applyWallpaper:");
}

function scheduleCheck(delay) {
  checkTimer = scheduleOnce(checkTimer, delay, "checkWallpaper:");
}

ObjC.registerSubclass({
  name: "WallpaperJourneyDisplayWatcher",
  protocols: ["NSApplicationDelegate"],
  methods: {
    "applicationDidChangeScreenParameters:": {
      types: ["void", ["id"]],
      implementation: function () {
        // macOS can post several notifications while a display settles.
        scheduleApply(2);
      },
    },
    "pollStore:": {
      types: ["void", ["id"]],
      implementation: function () {
        const stamp = storeStamp();
        if (stamp === 0 || stamp === lastStoreStamp) return;
        // Skip the very first reading, which only establishes a baseline.
        const known = lastStoreStamp !== 0;
        lastStoreStamp = stamp;
        if (known) scheduleCheck(1.5);
      },
    },
    "applyWallpaper:": {
      types: ["void", ["id"]],
      implementation: function () {
        applyTimer = null;
        runWallpaperScript("--apply");
      },
    },
    "checkWallpaper:": {
      types: ["void", ["id"]],
      implementation: function () {
        checkTimer = null;
        runWallpaperScript("--check");
      },
    },
  },
});

function run(argv) {
  if (argv.length !== 1) {
    throw new Error("usage: wallpaper-watcher.js /absolute/path/to/wallpaper.sh");
  }

  wallpaperScript = argv[0];
  const app = $.NSApplication.sharedApplication;
  delegate = $.WallpaperJourneyDisplayWatcher.alloc.init;
  app.delegate = delegate;
  app.setActivationPolicy($.NSApplicationActivationPolicyProhibited);

  // Watching the store's timestamp is what makes a manual wallpaper change
  // register within seconds. macOS no longer posts a notification for it, so
  // there is nothing to subscribe to. Reading one timestamp costs nothing, and
  // the script only runs when the file has actually changed.
  lastStoreStamp = storeStamp();
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    2,
    delegate,
    "pollStore:",
    null,
    true
  );

  // Backstop for anything the timestamp watch misses.
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    300,
    delegate,
    "checkWallpaper:",
    null,
    true
  );

  scheduleApply(1);
  app.run;
}
