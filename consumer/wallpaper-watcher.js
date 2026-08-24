#!/usr/bin/osascript -l JavaScript

ObjC.import("AppKit");
ObjC.import("Foundation");

let wallpaperScript = "";
let delegate = null;
let debounceTimer = null;

function scheduleApply(delay) {
  if (debounceTimer !== null) {
    debounceTimer.invalidate;
  }
  debounceTimer = $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    delay,
    delegate,
    "applyWallpaper:",
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
    "applyWallpaper:": {
      types: ["void", ["id"]],
      implementation: function () {
        debounceTimer = null;
        const task = $.NSTask.alloc.init;
        task.launchPath = "/bin/zsh";
        task.arguments = [wallpaperScript, "--apply"];
        task.launch;
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
  scheduleApply(1);
  app.run;
}
