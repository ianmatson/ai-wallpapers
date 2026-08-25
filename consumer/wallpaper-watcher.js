#!/usr/bin/osascript -l JavaScript

ObjC.import("AppKit");
ObjC.import("Foundation");

let wallpaperScript = "";
let delegate = null;
let applyTimer = null;
let followUpTimer = null;
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

// A Space switch reports itself before the switch has finished, so an apply
// sent straight away still lands on the Space being left. Sending a second one
// after the transition settles is what makes the new Space update on arrival
// instead of only after leaving and coming back.
function scheduleApplyPair(delay, followUpDelay) {
  scheduleApply(delay);
  if (followUpTimer !== null) {
    followUpTimer.invalidate;
  }
  followUpTimer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    followUpDelay,
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
    "activeSpaceChanged:": {
      types: ["void", ["id"]],
      implementation: function () {
        // Spaces set up by an older version still point at a dated filename,
        // so give each one the fixed path as it is visited. Once a Space has
        // been through this it keeps up on its own, because the daily run
        // replaces the bytes behind that path.
        scheduleApplyPair(0.6, 2.5);
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
        // Applying the same image twice costs nothing visible, so the pair of
        // timers above needs no bookkeeping beyond clearing itself.
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

  // Catch up whichever Space the user switches to.
  $.NSWorkspace.sharedWorkspace.notificationCenter.addObserverSelectorNameObject(
    delegate,
    "activeSpaceChanged:",
    $.NSWorkspaceActiveSpaceDidChangeNotification,
    $()
  );

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
