#!/usr/bin/osascript -l JavaScript

ObjC.import("AppKit");
ObjC.import("Foundation");

let wallpaperScript = "";
let delegate = null;
let applyTimer = null;
let checkTimer = null;

function runWallpaperScript(action) {
  const task = $.NSTask.alloc.init;
  task.launchPath = "/bin/zsh";
  task.arguments = [wallpaperScript, action];
  task.launch;
}

function scheduleApply(delay) {
  if (applyTimer !== null) {
    applyTimer.invalidate;
  }
  applyTimer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    delay,
    delegate,
    "applyWallpaper:",
    null,
    false
  );
}

function scheduleCheck(delay) {
  if (checkTimer !== null) {
    checkTimer.invalidate;
  }
  checkTimer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    delay,
    delegate,
    "checkWallpaper:",
    null,
    false
  );
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
    "desktopBackgroundChanged:": {
      types: ["void", ["id"]],
      implementation: function () {
        // Wait past the apply debounce above so a display change never gets
        // judged before our own reapply has run.
        scheduleCheck(8);
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
  delegate = $.DailyWallpaperDisplayWatcher.alloc.init;
  app.delegate = delegate;
  app.setActivationPolicy($.NSApplicationActivationPolicyProhibited);

  // A manual wallpaper change means the user opted out; --check then uninstalls
  // everything. The notification gives an instant reaction, the repeating timer
  // catches macOS versions where the notification never arrives.
  $.NSDistributedNotificationCenter.defaultCenter.addObserverSelectorNameObject(
    delegate,
    "desktopBackgroundChanged:",
    "com.apple.desktop",
    "BackgroundChanged"
  );
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
