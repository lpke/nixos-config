// Run through SSH with /usr/bin/osascript -l JavaScript -.
// AppKit reads focus without changing any Mac keyboard settings or requesting
// System Events automation access. Emit changes plus a one-second heartbeat.
ObjC.import("AppKit");
const output = $.NSFileHandle.fileHandleWithStandardOutput;
let previous = null;
let lastSent = 0;
while (true) {
  const application = $.NSWorkspace.sharedWorkspace.frontmostApplication;
  const bundle = application ? ObjC.unwrap(application.bundleIdentifier) || "" : "";
  const now = Date.now();
  if (bundle !== previous || now - lastSent >= 1000) {
    output.writeData($(bundle + "\n").dataUsingEncoding($.NSUTF8StringEncoding));
    previous = bundle;
    lastSent = now;
  }
  // NSWorkspace caches focus. Pump its run loop so activation notifications
  // refresh frontmostApplication instead of reporting the initial app forever.
  $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(0.05));
}
