{ lib }:

{
  kraken = {
    # Substring passed to liquidctl --match. Check candidates with:
    #   liquidctl list
    liquidctlMatch = "Kraken Z";

    # Curve points use { temp = celsius; percent = 0..100; }.
    # Kraken curves are based on coolant temp. Pump is forced to 100% at >= 60 C.
    pumpCurve = [
      { temp = 20; percent = 50; }
      { temp = 30; percent = 50; }
      { temp = 35; percent = 55; }
      { temp = 40; percent = 65; }
      { temp = 45; percent = 75; }
      { temp = 50; percent = 85; }
      { temp = 55; percent = 95; }
      { temp = 60; percent = 100; }
    ];

    # Controls the two Z53 radiator fans.
    radiatorFanCurve = [
      { temp = 20; percent = 25; }
      { temp = 30; percent = 25; }
      { temp = 35; percent = 30; }
      { temp = 40; percent = 45; }
      { temp = 45; percent = 65; }
      { temp = 50; percent = 85; }
      { temp = 55; percent = 100; }
      { temp = 60; percent = 100; }
    ];
  };

  grid = {
    # Creates /dev/<deviceSymlink> for the Grid+ V2 controller.
    deviceSymlink = "GridPlusV2";

    # USB serial matched by the udev rule. Check with:
    #   udevadm info --query=property --name=/dev/ttyACM0
    serial = "0002042774";

    # Live control loop rate. Grid+ V2 does not store fan curves in hardware.
    controlIntervalSeconds = 5;

    # Ignore target changes smaller than this many percentage points.
    hysteresisPercent = 5;

    # alpha: 1 = instant response, lower = smoother.
    # fallAlpha is lower so brief spikes settle quietly instead of bouncing.
    smoothSources = {
      cpu_smooth = {
        rawSource = "cpu";
        riseAlpha = 0.35;
        fallAlpha = 0.15;
      };
      gpu_smooth = {
        rawSource = "gpu";
        riseAlpha = 0.35;
        fallAlpha = 0.15;
      };
    };

    # Physical Grid+ V2 ports, keyed by channel number: "1".."6".
    # source options: "cpu", "liquid", "gpu", "max",
    # "cpu_smooth", "gpu_smooth", "max_smooth".
    # max_smooth = max(cpu_smooth, gpu_smooth, liquid).
    # Channels 3 and 5 are safe fallback curves for currently empty ports.
    channels = {
      "1" = {
        name = "Front bottom (GridFan1)";
        source = "liquid";
        curve = [
          { temp = 20; percent = 30; }
          { temp = 30; percent = 30; }
          { temp = 35; percent = 35; }
          { temp = 40; percent = 50; }
          { temp = 45; percent = 70; }
          { temp = 50; percent = 90; }
          { temp = 55; percent = 100; }
        ];
      };

      "2" = {
        name = "Front middle (GridFan2)";
        source = "liquid";
        curve = [
          { temp = 20; percent = 30; }
          { temp = 30; percent = 30; }
          { temp = 35; percent = 35; }
          { temp = 40; percent = 50; }
          { temp = 45; percent = 70; }
          { temp = 50; percent = 90; }
          { temp = 55; percent = 100; }
        ];
      };

      "3" = {
        name = "none (GridFan3)";
        source = "max_smooth";
        curve = [
          { temp = 30; percent = 30; }
          { temp = 45; percent = 30; }
          { temp = 55; percent = 40; }
          { temp = 65; percent = 55; }
          { temp = 75; percent = 75; }
          { temp = 85; percent = 100; }
        ];
      };

      "4" = {
        name = "Front top (GridFan4)";
        source = "max_smooth";
        curve = [
          { temp = 30; percent = 30; }
          { temp = 45; percent = 30; }
          { temp = 55; percent = 40; }
          { temp = 65; percent = 55; }
          { temp = 75; percent = 75; }
          { temp = 85; percent = 100; }
        ];
      };

      "5" = {
        name = "none (GridFan5)";
        source = "max_smooth";
        curve = [
          { temp = 30; percent = 30; }
          { temp = 45; percent = 30; }
          { temp = 55; percent = 40; }
          { temp = 65; percent = 55; }
          { temp = 75; percent = 75; }
          { temp = 85; percent = 100; }
        ];
      };

      "6" = {
        name = "Back top (GridFan6)";
        source = "max_smooth";
        curve = [
          { temp = 30; percent = 30; }
          { temp = 45; percent = 30; }
          { temp = 55; percent = 40; }
          { temp = 65; percent = 55; }
          { temp = 75; percent = 75; }
          { temp = 85; percent = 100; }
        ];
      };
    };
  };
}
