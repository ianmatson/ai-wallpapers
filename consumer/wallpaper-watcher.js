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
let followUpTimer = null;
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

// A Space switch reports itself before the switch has finished, so an action
// sent straight away still lands on the Space being left. Sending a second one
// after the transition settles is what makes the new Space be handled on
// arrival instead of only after leaving and coming back.
function scheduleVisitPair(delay, followUpDelay) {
  applyTimer = scheduleOnce(applyTimer, delay, "visitSpace:");
  followUpTimer = scheduleOnce(followUpTimer, followUpDelay, "visitSpace:");
}

ObjC.registerSubclass({
  name: "DailyWallpaperDisplayWatcher",
  protocols: ["NSApplicationDelegate"],
  methods: {
    "applicationDidChangeScreenParameters:": {
      types: ["void", ["id"]],
      implementation: function () {
        // macOS can post several notifications while a display settles.
        scheduleApply(2);
      },
    },
    "activeSpaceChanged:": {
      types: ["void", ["id"]],
      implementation: function () {
        // --visit stops the subscription if this Space carries a wallpaper the
        // user chose, and otherwise moves a Space set up by an older version
        // onto the fixed path.
        scheduleVisitPair(0.6, 2.5);
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
    "visitSpace:": {
      types: ["void", ["id"]],
      implementation: function () {
        runWallpaperScript("--visit");
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
  delegate = $.DailyWallpaperDisplayWatcher.alloc.init;
  app.delegate = delegate;
  app.setActivationPolicy($.NSApplicationActivationPolicyProhibited);

  // Handle whichever Space the user switches to.
  $.NSWorkspace.sharedWorkspace.notificationCenter.addObserverSelectorNameObject(
    delegate,
    "activeSpaceChanged:",
    $.NSWorkspaceActiveSpaceDidChangeNotification,
    $()
  );

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
