#!/usr/bin/osascript -l JavaScript

ObjC.import("AppKit");
ObjC.import("Foundation");

// The wallpaper agent rewrites this file whenever any wallpaper changes, on any
// Space, so its timestamp is the signal that the user has chosen their own.
const STORE_PATH = ObjC.unwrap($.NSHomeDirectory()) +
  "/Library/Application Support/com.apple.wallpaper/Store/Index.plist";

let wallpaperScript = "";
let systemEventMarkerPrefix = "";
let eventSerial = 0;
let delegate = null;
let applyTimer = null;
let checkTimer = null;
let spaceFollowupTimer = null;
let lastStoreStamp = 0;
let currentTask = null;
let currentAction = null;
let applyScheduled = false;
let pendingApply = false;
let pendingCheck = false;

function startWallpaperScript(action) {
  const task = $.NSTask.alloc.init;
  task.launchPath = "/bin/zsh";
  task.arguments = [wallpaperScript, action];
  currentTask = task;
  currentAction = action;
  try {
    task.launch;
  } catch (error) {
    console.log("could not start " + action + ": " + error);
    currentTask = null;
    currentAction = null;
  }
}

function pumpTasks() {
  if (currentTask !== null && currentTask.isRunning) return;
  if (currentTask !== null) {
    const result = Number(currentTask.terminationStatus);
    if (result !== 0) console.log(currentAction + " exited with status " + result);
    currentTask = null;
    currentAction = null;
  }

  if (pendingApply) {
    pendingApply = false;
    startWallpaperScript("--apply");
    return;
  }
  // A known system change must apply before a store check can interpret the
  // transient wallpaper as a user opt-out.
  if (applyScheduled) return;
  if (pendingCheck) {
    pendingCheck = false;
    startWallpaperScript("--check");
  }
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
  // Publish the event before the timer starts. A --check task that is already
  // in its confirmation delay can then leave the transient desktop alone.
  eventSerial += 1;
  const token = Number($.NSProcessInfo.processInfo.processIdentifier) + "-" +
    Date.now() + "-" + eventSerial;
  if (!$.NSData.data.writeToFileAtomically(systemEventMarkerPrefix + token, true)) {
    console.log("could not write the system-event marker");
  }
  applyScheduled = true;
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
    "workspaceDidWake:": {
      types: ["void", ["id"]],
      implementation: function () {
        // Give the wallpaper service time to restore the active desktop.
        scheduleApply(3);
      },
    },
    "workspaceActiveSpaceDidChange:": {
      types: ["void", ["id"]],
      implementation: function () {
        // The first pass catches a normal switch. The follow-up catches rapid
        // switches and transitions whose first notification arrives too soon.
        scheduleApply(0.6);
        spaceFollowupTimer = scheduleOnce(
          spaceFollowupTimer,
          2.5,
          "applySpaceFollowup:"
        );
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
        applyScheduled = false;
        pendingApply = true;
        pumpTasks();
      },
    },
    "applySpaceFollowup:": {
      types: ["void", ["id"]],
      implementation: function () {
        spaceFollowupTimer = null;
        scheduleApply(0.1);
      },
    },
    "checkWallpaper:": {
      types: ["void", ["id"]],
      implementation: function () {
        checkTimer = null;
        pendingCheck = true;
        pumpTasks();
      },
    },
    "pollTask:": {
      types: ["void", ["id"]],
      implementation: function () {
        pumpTasks();
      },
    },
  },
});

function run(argv) {
  if (argv.length !== 1) {
    throw new Error("usage: wallpaper-watcher.js /absolute/path/to/wallpaper.sh");
  }

  wallpaperScript = argv[0];
  systemEventMarkerPrefix = wallpaperScript.replace(
    /\/[^/]+$/,
    "/.system-change-pending."
  );
  const app = $.NSApplication.sharedApplication;
  delegate = $.WallpaperJourneyDisplayWatcher.alloc.init;
  app.delegate = delegate;
  app.setActivationPolicy($.NSApplicationActivationPolicyProhibited);

  const workspaceNotifications = $.NSWorkspace.sharedWorkspace.notificationCenter;
  workspaceNotifications.addObserverSelectorNameObject(
    delegate,
    "workspaceDidWake:",
    $.NSWorkspaceDidWakeNotification,
    null
  );
  workspaceNotifications.addObserverSelectorNameObject(
    delegate,
    "workspaceActiveSpaceDidChange:",
    $.NSWorkspaceActiveSpaceDidChangeNotification,
    null
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

  // NSTask completion callbacks are unreliable in long-running JXA scripts.
  // Poll one owned task and start at most one coalesced follow-up action.
  $.NSTimer.scheduledTimerWithTimeIntervalTargetSelectorUserInfoRepeats(
    0.25,
    delegate,
    "pollTask:",
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
