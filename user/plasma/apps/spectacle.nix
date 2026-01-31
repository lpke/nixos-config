# These settings are imported and merged into the rest of the plasma-manager config

{
  spectacle = {
    shortcuts = {
      launch = "Meta+Alt+Shift+S"; # default: Meta+Shift+s, Print (now yakuake)
      launchWithoutCapturing = [];
      captureActiveWindow = [];
      captureCurrentMonitor = [];
      captureEntireDesktop = [];
      captureRectangularRegion = [];
      captureWindowUnderCursor = [];
      recordRegion = [];
      recordScreen = [];
      recordWindow = [];
    };
  };

  configFile = {
    spectaclerc = {
      # screenshots
      ImageSave.imageSaveLocation = "file:///home/luke/Pictures/Screenshots";
      ImageSave.imageFilenameTemplate = "screenshot_<yyyy>-<MM>-<dd>_<HH><mm><ss>";
      ImageSave.translatedScreenshotsFolder = "Screenshots";
      Annotations.annotationToolType = 1;
      # videos
      VideoSave.videoFilenameTemplate = "recording_<yyyy>-<MM>-<dd>_<HH><mm><ss>";
      VideoSave.videoSaveLocation = "file:///home/luke/Videos/Recordings/";
      VideoSave.translatedScreencastsFolder = "Recordings";
      VideoSave.preferredVideoFormat = 2;
    };
  };
}
