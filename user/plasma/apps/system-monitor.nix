{ lib
, fanControl ? import ../../../system/fan-control/config.nix { inherit lib; }
}:

let
  raw = value: {
    inherit value;
    escapeValue = false;
  };

  sensorList = ids:
    raw "[${lib.concatMapStringsSep "," (id: ''"${id}"'') ids}]";

  merge = attrs: lib.foldl' lib.recursiveUpdate {} attrs;
  maybe = condition: attrs: lib.optionalAttrs condition attrs;

  colors = {
    blue = "61,174,233";
    green = "106,190,48";
    orange = "233,120,61";
    red = "233,61,97";
    coral = "255,94,79";
    purple = "180,140,255";
    yellow = "245,193,66";
    cyan = "56,189,248";
    gray = "160,160,160";
  };

  lineGeneral = {
    historyAmount = 300;
    lineChartFillOpacity = 15;
    lineChartSmooth = false;
    showGridLines = true;
    showYAxisLabels = true;
  };

  percentGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 100;
  };

  temperatureGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 100;
  };

  cpuFrequencyGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 6000;
  };

  gpuFrequencyGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 10000;
  };

  fanGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 4000;
  };

  powerGeneral = lineGeneral // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 600;
  };

  autoGeneral = lineGeneral // {
    rangeAutoY = true;
  };

  mkSensorConfig = { high, low ? [], total ? [] }:
    { highPrioritySensorIds = sensorList high; }
    // maybe (low != []) { lowPrioritySensorIds = sensorList low; }
    // maybe (total != []) { totalSensors = sensorList total; };

  mkFace =
    { name
    , title
    , chartFace
    , sensors ? null
    , sensorColors ? {}
    , sensorLabels ? {}
    , generalPath ? null
    , general ? {}
    , appearance ? {}
    }:
    let
      face = "Face-${name}";
    in
    {
      "${face}/Appearance" = {
        Title = title;
        inherit chartFace;
      } // appearance;
    }
    // maybe (sensors != null) { "${face}/Sensors" = sensors; }
    // maybe (sensorColors != {}) { "${face}/SensorColors" = sensorColors; }
    // maybe (sensorLabels != {}) { "${face}/SensorLabels" = sensorLabels; }
    // maybe (generalPath != null) { "${face}/${generalPath}" = general; };

  mkLineFace =
    { name
    , title
    , ids
    , low ? []
    , total ? []
    , sensorColors ? {}
    , sensorLabels ? {}
    , general ? autoGeneral
    }:
    mkFace {
      inherit name title sensorColors sensorLabels general;
      chartFace = "org.kde.ksysguard.linechart";
      sensors = mkSensorConfig { high = ids; inherit low total; };
      generalPath = "org.kde.ksysguard.linechart/General";
    };

  mkPieFace =
    { name
    , title
    , ids
    , low ? []
    , total ? ids
    , sensorColors ? {}
    , sensorLabels ? {}
    , general ? { showLegend = false; }
    }:
    mkFace {
      inherit name title sensorColors sensorLabels general;
      chartFace = "org.kde.ksysguard.piechart";
      sensors = mkSensorConfig { high = ids; inherit low total; };
      generalPath = "org.kde.ksysguard.piechart/General";
    };

  mkTextFace =
    { name
    , title
    , ids
    , low ? []
    , sensorColors ? {}
    , sensorLabels ? {}
    , general ? { groupByTotal = false; }
    , appearance ? {}
    }:
    mkFace {
      inherit name title sensorColors sensorLabels general appearance;
      chartFace = "org.kde.ksysguard.textonly";
      sensors = mkSensorConfig { high = ids; inherit low; };
      generalPath = "org.kde.ksysguard.textonly/General";
    };

  mkBarFace =
    { name
    , title
    , ids
    , low ? []
    , sensorColors ? {}
    , sensorLabels ? {}
    }:
    mkFace {
      inherit name title sensorColors sensorLabels;
      chartFace = "org.kde.ksysguard.horizontalbars";
      sensors = mkSensorConfig { high = ids; inherit low; };
    };

  mkProcessFace = { name, title }:
    mkFace {
      inherit name title;
      chartFace = "org.kde.ksysguard.processtable";
      appearance = { showTitle = true; };
    };

  mkPage = { title, icon, rows }:
    let
      mkColumn = rowIndex: columnIndex: column:
        let
          rowKey = "page/row-${toString rowIndex}";
          columnKey = "${rowKey}/column-${toString columnIndex}";
        in
        {
          "${columnKey}" = {
            name = "column-${toString columnIndex}";
            noMargins = column.noMargins or false;
            showBackground = column.showBackground or true;
          };

          "${columnKey}/section-0" = {
            inherit (column) face;
            isSeparator = false;
            name = "section-0";
          };
        };

      mkRow = rowIndex: row:
        let
          rowKey = "page/row-${toString rowIndex}";
        in
        {
          "${rowKey}" = {
            Title = row.title or "";
            heightMode = row.heightMode or "minimum";
            isTitle = row.isTitle or false;
            name = "row-${toString rowIndex}";
          };
        }
        // merge (lib.imap0 (columnIndex: column:
          mkColumn rowIndex columnIndex column
        ) (row.columns or []));
    in
    {
      page = {
        Title = title;
        actionsFace = "";
        inherit icon;
        loadType = "onstart";
        margin = 2;
        version = 1;
      };
    }
    // merge (lib.imap0 mkRow rows);

  cpuSummaryIds = [
    "cpu/all/averageTemperature"
    "cpu/all/maximumTemperature"
    "cpu/all/averageFrequency"
  ];

  gpuSummaryIds = [
    "gpu/gpu1/usage"
    "gpu/gpu1/temperature"
    "gpu/gpu1/coreFrequency"
    "gpu/gpu1/memoryFrequency"
    "gpu/gpu1/usedVram"
    "gpu/gpu1/power"
  ];

  monitorGpuDetailIds = [
    "gpu/gpu1/temperature"
    "gpu/gpu1/coreFrequency"
    "gpu/gpu1/memoryFrequency"
    "gpu/gpu1/usedVram"
    "gpu/gpu1/power"
  ];

  memorySummaryIds = [
    "memory/physical/used"
    "memory/physical/free"
    "memory/swap/usedPercent"
  ];

  storageSummaryIds = [
    "disk/all/used"
    "disk/all/free"
    "disk/all/read"
    "disk/all/write"
  ];

  networkRateIds = [
    "network/all/download"
    "network/all/upload"
  ];

  networkTotalIds = [
    "network/all/totalDownload"
    "network/all/totalUpload"
  ];

  gridChannelColors = {
    "1" = colors.blue;
    "2" = colors.green;
    "3" = colors.gray;
    "4" = colors.orange;
    "5" = colors.gray;
    "6" = colors.purple;
  };

  gridChannels = lib.mapAttrsToList
    (channel: settings: {
      inherit channel;
      inherit (settings) name;
      color = gridChannelColors.${channel} or colors.gray;
    })
    fanControl.grid.channels;

  gridMetrics = [
    { key = "rpm"; label = "RPM"; unit = "UnitRpm"; }
    { key = "percent"; label = "Actual"; unit = "UnitPercent"; }
    { key = "target_percent"; label = "Target"; unit = "UnitPercent"; }
    { key = "voltage"; label = "Voltage"; unit = "UnitVolt"; }
    { key = "wattage"; label = "Power"; unit = "UnitWatt"; }
  ];

  gridRawSensorId = channel: metric: "grid_v2_ch${channel}_${metric}";
  gridKdeSensorId = channel: metric:
    "custom_sensor_container/custom_sensor_object/${gridRawSensorId channel metric}";
  gridMetricPath = channel: metric: "/run/nzxt-grid-v2/channel_${channel}_${metric}";

  gridMetricIds = metric:
    map (gridChannel: gridKdeSensorId gridChannel.channel metric) gridChannels;

  gridMetricLabels = metric: label:
    lib.listToAttrs (map (gridChannel: {
      name = gridKdeSensorId gridChannel.channel metric;
      value =
        if label == ""
        then gridChannel.name
        else "${gridChannel.name} ${label}";
    }) gridChannels);

  gridMetricColors = metric:
    lib.listToAttrs (map (gridChannel: {
      name = gridKdeSensorId gridChannel.channel metric;
      value = gridChannel.color;
    }) gridChannels);

  sensorBlock = { id, name, file, unit }: ''
    [Sensor]
    id=${id}
    name=${name}
    file=${file}
    unit=${unit}
  '';

  gridSensorBlocks = lib.flatten (map (gridChannel:
    map (metric: sensorBlock {
      id = gridRawSensorId gridChannel.channel metric.key;
      name = "Grid+ V2 ${gridChannel.name} ${metric.label}";
      file = gridMetricPath gridChannel.channel metric.key;
      unit = metric.unit;
    }) gridMetrics
  ) gridChannels);

  customSensorConfigFile = {
    # The KSystemStats custom sensors plugin reads this upstream config path and turns
    # these files into real KDE System Monitor sensor IDs.
    "customsensorrc".text = lib.concatStringsSep "\n" gridSensorBlocks;
  };

  krakenSensorPrefix = "lmsensors/z53-hid-[0-9]+-[0-9]+";
  krakenCoolantId = "${krakenSensorPrefix}/temp1";
  krakenCurrentCoolantId = "lmsensors/z53-hid-3-7/temp1";
  krakenPumpRpmId = "${krakenSensorPrefix}/fan1";
  krakenRadiatorFanRpmId = "${krakenSensorPrefix}/fan2";

  krakenLabels = {
    "${krakenCoolantId}" = "Coolant";
    "${krakenPumpRpmId}" = "Pump";
    "${krakenRadiatorFanRpmId}" = "Radiator fan";
  };

  krakenFanIds = [
    krakenPumpRpmId
    krakenRadiatorFanRpmId
  ];

  krakenFanColors = {
    "${krakenPumpRpmId}" = colors.green;
    "${krakenRadiatorFanRpmId}" = colors.orange;
  };

  fanRpmIds = gridMetricIds "rpm";
  fanRpmLabels = gridMetricLabels "rpm" "";
  fanRpmColors = gridMetricColors "rpm";

  coolingGraphIds = [
    "cpu/all/averageTemperature"
    "gpu/gpu1/temperature"
    krakenCoolantId
  ];

  coolingGraphColors = {
    "cpu/all/averageTemperature" = colors.blue;
    "gpu/gpu1/temperature" = colors.green;
    "${krakenCurrentCoolantId}" = colors.gray;
    "${krakenCoolantId}" = colors.gray;
  };

  coolingGraphLabels = {
    "cpu/all/averageTemperature" = "CPU";
    "gpu/gpu1/temperature" = "GPU";
    "${krakenCoolantId}" = "Coolant";
  };

  moboFanIds = [
    "lmsensors/nct6798-isa-0290/fan1"
    "lmsensors/nct6798-isa-0290/fan2"
    "lmsensors/nct6798-isa-0290/fan3"
    "lmsensors/nct6798-isa-0290/fan4"
    "lmsensors/nct6798-isa-0290/fan5"
    "lmsensors/nct6798-isa-0290/fan6"
    "lmsensors/nct6798-isa-0290/fan7"
  ];

  moboFanLabels = {
    "lmsensors/nct6798-isa-0290/fan1" = "Fan 1";
    "lmsensors/nct6798-isa-0290/fan2" = "Fan 2 / CPU tach";
    "lmsensors/nct6798-isa-0290/fan3" = "Fan 3";
    "lmsensors/nct6798-isa-0290/fan4" = "Fan 4";
    "lmsensors/nct6798-isa-0290/fan5" = "Fan 5";
    "lmsensors/nct6798-isa-0290/fan6" = "Fan 6";
    "lmsensors/nct6798-isa-0290/fan7" = "Fan 7";
  };

  moboFanColors = {
    "lmsensors/nct6798-isa-0290/fan1" = colors.gray;
    "lmsensors/nct6798-isa-0290/fan2" = colors.green;
    "lmsensors/nct6798-isa-0290/fan3" = colors.blue;
    "lmsensors/nct6798-isa-0290/fan4" = colors.orange;
    "lmsensors/nct6798-isa-0290/fan5" = colors.purple;
    "lmsensors/nct6798-isa-0290/fan6" = colors.yellow;
    "lmsensors/nct6798-isa-0290/fan7" = colors.red;
  };

  ramTempId = address: "lmsensors/spd5118-i2c-[0-9]+-${address}/temp1";

  ramTempIds = map ramTempId [ "50" "51" "52" "53" ];

  ramTempLabels = {
    "${ramTempId "50"}" = "DIMM 1";
    "${ramTempId "51"}" = "DIMM 2";
    "${ramTempId "52"}" = "DIMM 3";
    "${ramTempId "53"}" = "DIMM 4";
  };

  ramTempColors = {
    "${ramTempId "50"}" = colors.blue;
    "${ramTempId "51"}" = colors.green;
    "${ramTempId "52"}" = colors.orange;
    "${ramTempId "53"}" = colors.purple;
  };

  nvmeTempIds = [
    "lmsensors/nvme-pci-0200/temp1"
    "lmsensors/nvme-pci-0200/temp3"
    "lmsensors/nvme-pci-7100/temp1"
    "lmsensors/nvme-pci-7100/temp2"
    "lmsensors/nvme-pci-7100/temp3"
  ];

  nvmeTempLabels = {
    "lmsensors/nvme-pci-0200/temp1" = "NVMe 0200 Composite";
    "lmsensors/nvme-pci-0200/temp3" = "NVMe 0200 Sensor 2";
    "lmsensors/nvme-pci-7100/temp1" = "NVMe 7100 Composite";
    "lmsensors/nvme-pci-7100/temp2" = "NVMe 7100 Sensor 1";
    "lmsensors/nvme-pci-7100/temp3" = "NVMe 7100 Sensor 2";
  };

  nvmeTempColors = {
    "lmsensors/nvme-pci-0200/temp1" = colors.blue;
    "lmsensors/nvme-pci-0200/temp3" = colors.orange;
    "lmsensors/nvme-pci-7100/temp1" = colors.green;
    "lmsensors/nvme-pci-7100/temp2" = colors.purple;
    "lmsensors/nvme-pci-7100/temp3" = colors.red;
  };

  usefulMoboTempIds = [
    "lmsensors/nct6798-isa-0290/temp1"
    "lmsensors/nct6798-isa-0290/temp2"
    "lmsensors/nct6798-isa-0290/temp3"
    "lmsensors/nct6798-isa-0290/temp4"
    "lmsensors/nct6798-isa-0290/temp6"
    "lmsensors/nct6798-isa-0290/temp8"
    "lmsensors/nct6798-isa-0290/temp9"
    "lmsensors/nct6798-isa-0290/temp11"
  ];

  usefulMoboTempLabels = {
    "lmsensors/nct6798-isa-0290/temp1" = "SYSTIN";
    "lmsensors/nct6798-isa-0290/temp2" = "CPUTIN";
    "lmsensors/nct6798-isa-0290/temp3" = "AUXTIN0";
    "lmsensors/nct6798-isa-0290/temp4" = "AUXTIN1";
    "lmsensors/nct6798-isa-0290/temp6" = "AUXTIN3";
    "lmsensors/nct6798-isa-0290/temp8" = "PECI Agent 0";
    "lmsensors/nct6798-isa-0290/temp9" = "PECI Calibration";
    "lmsensors/nct6798-isa-0290/temp11" = "PCH";
  };

  moboVoltageIds = [
    "lmsensors/nct6798-isa-0290/in0"
    "lmsensors/nct6798-isa-0290/in1"
    "lmsensors/nct6798-isa-0290/in2"
    "lmsensors/nct6798-isa-0290/in3"
    "lmsensors/nct6798-isa-0290/in4"
    "lmsensors/nct6798-isa-0290/in5"
    "lmsensors/nct6798-isa-0290/in6"
    "lmsensors/nct6798-isa-0290/in7"
    "lmsensors/nct6798-isa-0290/in8"
    "lmsensors/nct6798-isa-0290/in9"
    "lmsensors/nct6798-isa-0290/in10"
    "lmsensors/nct6798-isa-0290/in11"
    "lmsensors/nct6798-isa-0290/in12"
    "lmsensors/nct6798-isa-0290/in13"
    "lmsensors/nct6798-isa-0290/in14"
  ];

  ambientTempIds = [
    "lmsensors/acpitz-acpi-0/temp1"
    "lmsensors/iwlwifi_1-virtual-0/temp1"
  ];

  faces = merge [
    (mkPieFace {
      name = "monitor-cpu-load";
      title = "CPU";
      ids = [ "cpu/all/usage" ];
      sensorColors = { "cpu/all/usage" = colors.blue; };
      sensorLabels = {
        "cpu/all/usage" = "Load";
      };
    })

    (mkTextFace {
      name = "monitor-cpu";
      title = "CPU";
      ids = cpuSummaryIds;
      appearance = {
        showTitle = false;
        title = "CPU Data";
      };
      sensorColors = {
        "cpu/all/averageFrequency" = colors.yellow;
        "cpu/all/averageTemperature" = colors.coral;
        "cpu/all/maximumTemperature" = colors.red;
        "cpu/all/usage" = colors.blue;
        "cpu/loadaverages/loadaverage1" = colors.green;
      };
      sensorLabels = {
        "cpu/all/usage" = "Load";
        "cpu/all/averageTemperature" = "Average temp";
        "cpu/all/maximumTemperature" = "Max temp";
        "cpu/all/averageFrequency" = "Average clock";
        "cpu/loadaverages/loadaverage1" = "Load average";
      };
    })

    (mkPieFace {
      name = "monitor-gpu-load";
      title = "GPU";
      ids = [ "gpu/gpu1/usage" ];
      sensorColors = { "gpu/gpu1/usage" = colors.green; };
      sensorLabels = {
        "gpu/gpu1/usage" = "Load";
      };
    })

    (mkTextFace {
      name = "monitor-gpu";
      title = "GPU";
      ids = gpuSummaryIds;
      sensorLabels = {
        "gpu/gpu1/usage" = "Load";
        "gpu/gpu1/temperature" = "Temp";
        "gpu/gpu1/coreFrequency" = "Core clock";
        "gpu/gpu1/memoryFrequency" = "Memory clock";
        "gpu/gpu1/usedVram" = "VRAM used";
        "gpu/gpu1/power" = "Power";
      };
    })

    (mkTextFace {
      name = "monitor-gpu-details";
      title = "GPU";
      ids = monitorGpuDetailIds;
      appearance = {
        showTitle = false;
        title = "GPU Data";
      };
      sensorColors = {
        "gpu/gpu1/coreFrequency" = colors.yellow;
        "gpu/gpu1/memoryFrequency" = colors.yellow;
        "gpu/gpu1/power" = colors.green;
        "gpu/gpu1/temperature" = colors.red;
        "gpu/gpu1/usage" = colors.green;
        "gpu/gpu1/usedVram" = colors.purple;
      };
      sensorLabels = {
        "gpu/gpu1/usage" = "Load";
        "gpu/gpu1/temperature" = "Temp";
        "gpu/gpu1/coreFrequency" = "Core clock";
        "gpu/gpu1/memoryFrequency" = "Memory clock";
        "gpu/gpu1/usedVram" = "VRAM used";
        "gpu/gpu1/power" = "Power";
      };
    })

    (mkPieFace {
      name = "monitor-memory";
      title = "RAM";
      ids = [ "memory/physical/usedPercent" ];
      sensorColors = { "memory/physical/usedPercent" = colors.purple; };
      sensorLabels = {
        "memory/physical/usedPercent" = "Used";
      };
    })

    (mkTextFace {
      name = "monitor-memory-details";
      title = "RAM";
      ids = memorySummaryIds;
      appearance = {
        showTitle = false;
        title = "RAM Data";
      };
      sensorColors = {
        "disk/all/usedPercent" = colors.cyan;
        "memory/physical/application" = colors.purple;
        "memory/physical/cache" = colors.red;
        "memory/physical/free" = colors.green;
        "memory/physical/used" = colors.purple;
        "memory/physical/usedPercent" = colors.blue;
        "memory/swap/usedPercent" = colors.yellow;
      };
      sensorLabels = {
        "memory/physical/usedPercent" = "Used";
        "memory/physical/application" = "Applications";
        "memory/physical/cache" = "Cache";
        "memory/physical/free" = "Free";
        "memory/swap/usedPercent" = "Swap";
      };
    })

    (mkPieFace {
      name = "monitor-storage";
      title = "Storage";
      ids = [ "disk/all/usedPercent" ];
      sensorColors = { "disk/all/usedPercent" = colors.yellow; };
      sensorLabels = {
        "disk/all/usedPercent" = "Used";
      };
    })

    (mkTextFace {
      name = "monitor-storage-details";
      title = "Storage";
      ids = storageSummaryIds;
      appearance = {
        showTitle = false;
        title = "Storage Data";
      };
      sensorColors = {
        "disk/all/free" = colors.green;
        "disk/all/read" = colors.orange;
        "disk/all/used" = colors.yellow;
        "disk/all/usedPercent" = colors.blue;
        "disk/all/write" = colors.orange;
      };
      sensorLabels = {
        "disk/all/usedPercent" = "Used";
        "disk/all/free" = "Free";
        "disk/all/read" = "Read";
        "disk/all/write" = "Write";
      };
    })

    (mkLineFace {
      name = "monitor-network";
      title = "Network";
      ids = networkRateIds;
      low = networkTotalIds;
      sensorColors = {
        "network/all/download" = colors.blue;
        "network/all/upload" = colors.orange;
      };
      sensorLabels = {
        "network/all/download" = "Download";
        "network/all/upload" = "Upload";
        "network/all/totalDownload" = "Downloaded";
        "network/all/totalUpload" = "Uploaded";
      };
      general = autoGeneral;
    })

    (mkLineFace {
      name = "monitor-cooling";
      title = "Cooling";
      ids = coolingGraphIds;
      sensorColors = coolingGraphColors;
      sensorLabels = coolingGraphLabels;
      general = temperatureGeneral;
    })

    (mkLineFace {
      name = "monitor-grid";
      title = "Case Fan RPM";
      ids = fanRpmIds;
      sensorColors = fanRpmColors;
      sensorLabels = fanRpmLabels;
      general = fanGeneral;
    })

    (mkLineFace {
      name = "inspect-cpu-load-history";
      title = "CPU Load History";
      ids = [ "cpu/all/usage" ];
      sensorColors = { "cpu/all/usage" = colors.blue; };
      general = percentGeneral;
    })

    (mkLineFace {
      name = "inspect-cpu-temps";
      title = "CPU Temperatures";
      ids = [
        "cpu/all/minimumTemperature"
        "cpu/all/averageTemperature"
        "cpu/all/maximumTemperature"
      ];
      sensorColors = {
        "cpu/all/minimumTemperature" = colors.cyan;
        "cpu/all/averageTemperature" = colors.orange;
        "cpu/all/maximumTemperature" = colors.red;
      };
      sensorLabels = {
        "cpu/all/minimumTemperature" = "Minimum";
        "cpu/all/averageTemperature" = "Average";
        "cpu/all/maximumTemperature" = "Maximum";
      };
      general = temperatureGeneral;
    })

    (mkLineFace {
      name = "inspect-cpu-frequency";
      title = "CPU Frequency";
      ids = [
        "cpu/all/minimumFrequency"
        "cpu/all/averageFrequency"
        "cpu/all/maximumFrequency"
      ];
      sensorColors = {
        "cpu/all/minimumFrequency" = colors.cyan;
        "cpu/all/averageFrequency" = colors.blue;
        "cpu/all/maximumFrequency" = colors.orange;
      };
      sensorLabels = {
        "cpu/all/minimumFrequency" = "Minimum";
        "cpu/all/averageFrequency" = "Average";
        "cpu/all/maximumFrequency" = "Maximum";
      };
      general = cpuFrequencyGeneral;
    })

    (mkBarFace {
      name = "inspect-core-usage";
      title = "Per-Core Load";
      ids = [ "cpu/cpu[0-9]+/usage" ];
      sensorColors = { "cpu/cpu[0-9]+/usage" = colors.blue; };
    })

    (mkBarFace {
      name = "inspect-core-temps";
      title = "Per-Core Temperatures";
      ids = [ "cpu/cpu[0-9]+/temperature" ];
      sensorColors = { "cpu/cpu[0-9]+/temperature" = colors.orange; };
    })

    (mkBarFace {
      name = "inspect-core-frequency";
      title = "Per-Core Frequency";
      ids = [ "cpu/cpu[0-9]+/frequency" ];
      sensorColors = { "cpu/cpu[0-9]+/frequency" = colors.purple; };
    })

    (mkLineFace {
      name = "inspect-gpu-load-history";
      title = "GPU Load History";
      ids = [ "gpu/gpu1/usage" ];
      sensorColors = { "gpu/gpu1/usage" = colors.green; };
      general = percentGeneral;
    })

    (mkLineFace {
      name = "inspect-gpu-temperature";
      title = "GPU Temperature";
      ids = [ "gpu/gpu1/temperature" ];
      sensorColors = {
        "gpu/gpu1/temperature" = colors.orange;
      };
      sensorLabels = {
        "gpu/gpu1/temperature" = "Temperature";
      };
      general = temperatureGeneral;
    })

    (mkLineFace {
      name = "inspect-gpu-frequency";
      title = "GPU Frequencies";
      ids = [
        "gpu/gpu1/coreFrequency"
        "gpu/gpu1/memoryFrequency"
      ];
      sensorColors = {
        "gpu/gpu1/coreFrequency" = colors.blue;
        "gpu/gpu1/memoryFrequency" = colors.purple;
      };
      sensorLabels = {
        "gpu/gpu1/coreFrequency" = "Core";
        "gpu/gpu1/memoryFrequency" = "Memory";
      };
      general = gpuFrequencyGeneral;
    })

    (mkLineFace {
      name = "inspect-gpu-vram";
      title = "GPU VRAM";
      ids = [ "gpu/gpu1/usedVram" ];
      low = [ "gpu/gpu1/totalVram" ];
      sensorColors = { "gpu/gpu1/usedVram" = colors.purple; };
      sensorLabels = { "gpu/gpu1/usedVram" = "Used"; };
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-gpu-power";
      title = "GPU Power";
      ids = [ "gpu/gpu1/power" ];
      sensorColors = { "gpu/gpu1/power" = colors.yellow; };
      sensorLabels = { "gpu/gpu1/power" = "Power"; };
      general = powerGeneral;
    })

    (mkLineFace {
      name = "inspect-kraken-liquid";
      title = "Kraken Coolant";
      ids = [ krakenCoolantId ];
      sensorColors = { "${krakenCoolantId}" = colors.cyan; };
      sensorLabels = { "${krakenCoolantId}" = "Coolant"; };
      general = temperatureGeneral;
    })

    (mkLineFace {
      name = "inspect-kraken-fans";
      title = "Kraken Pump and Radiator";
      ids = krakenFanIds;
      sensorColors = krakenFanColors;
      sensorLabels = krakenLabels;
      general = fanGeneral;
    })

    (mkLineFace {
      name = "inspect-mobo-fans";
      title = "Motherboard Fan Headers";
      ids = moboFanIds;
      sensorColors = moboFanColors;
      sensorLabels = moboFanLabels;
      general = fanGeneral;
    })

    (mkLineFace {
      name = "inspect-grid-rpm";
      title = "Grid+ V2 Case Fan RPM";
      ids = fanRpmIds;
      sensorColors = fanRpmColors;
      sensorLabels = fanRpmLabels;
      general = fanGeneral;
    })

    (mkLineFace {
      name = "inspect-grid-percent";
      title = "Grid+ V2 Actual Fan Percent";
      ids = gridMetricIds "percent";
      sensorColors = gridMetricColors "percent";
      sensorLabels = gridMetricLabels "percent" "actual";
      general = percentGeneral;
    })

    (mkLineFace {
      name = "inspect-grid-target";
      title = "Grid+ V2 Curve Targets";
      ids = gridMetricIds "target_percent";
      sensorColors = gridMetricColors "target_percent";
      sensorLabels = gridMetricLabels "target_percent" "target";
      general = percentGeneral;
    })

    (mkLineFace {
      name = "inspect-grid-voltage";
      title = "Grid+ V2 Fan Voltage";
      ids = gridMetricIds "voltage";
      sensorColors = gridMetricColors "voltage";
      sensorLabels = gridMetricLabels "voltage" "voltage";
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-grid-wattage";
      title = "Grid+ V2 Fan Power";
      ids = gridMetricIds "wattage";
      sensorColors = gridMetricColors "wattage";
      sensorLabels = gridMetricLabels "wattage" "power";
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-mobo-temps";
      title = "Motherboard Temperatures";
      ids = usefulMoboTempIds;
      sensorLabels = usefulMoboTempLabels;
      general = temperatureGeneral;
    })

    (mkPieFace {
      name = "inspect-memory";
      title = "Physical Memory";
      ids = [ "memory/physical/used" ];
      low = [
        "memory/physical/usedPercent"
        "memory/physical/application"
        "memory/physical/cache"
        "memory/physical/free"
      ];
      total = [
        "memory/physical/used"
        "memory/physical/total"
      ];
      sensorColors = { "memory/physical/used" = colors.blue; };
      general = { showLegend = true; };
    })

    (mkPieFace {
      name = "inspect-swap";
      title = "Swap";
      ids = [ "memory/swap/used" ];
      low = [
        "memory/swap/usedPercent"
        "memory/swap/free"
      ];
      total = [
        "memory/swap/used"
        "memory/swap/total"
      ];
      sensorColors = { "memory/swap/used" = colors.purple; };
      general = { showLegend = true; };
    })

    (mkLineFace {
      name = "inspect-ram-temps";
      title = "RAM Temperatures";
      ids = ramTempIds;
      sensorColors = ramTempColors;
      sensorLabels = ramTempLabels;
      general = temperatureGeneral;
    })

    (mkBarFace {
      name = "inspect-disk-usage";
      title = "Disk Usage";
      ids = [
        "disk/all/usedPercent"
        "disk/(?!all).*/usedPercent"
      ];
      low = [
        "disk/all/free"
        "disk/all/total"
      ];
      sensorColors = {
        "disk/all/usedPercent" = colors.blue;
        "disk/(?!all).*/usedPercent" = colors.green;
      };
      sensorLabels = {
        "disk/all/usedPercent" = "All disks";
        "disk/(?!all).*/usedPercent" = "Volumes/devices";
      };
    })

    (mkLineFace {
      name = "inspect-disk-io";
      title = "Disk I/O";
      ids = [
        "disk/all/read"
        "disk/all/write"
      ];
      sensorColors = {
        "disk/all/read" = colors.blue;
        "disk/all/write" = colors.orange;
      };
      sensorLabels = {
        "disk/all/read" = "Read";
        "disk/all/write" = "Write";
      };
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-nvme-temps";
      title = "NVMe Temperatures";
      ids = nvmeTempIds;
      sensorColors = nvmeTempColors;
      sensorLabels = nvmeTempLabels;
      general = temperatureGeneral;
    })

    (mkLineFace {
      name = "inspect-nvme-io";
      title = "NVMe I/O";
      ids = [
        "disk/nvme0n1/read"
        "disk/nvme0n1/write"
        "disk/nvme1n1/read"
        "disk/nvme1n1/write"
      ];
      sensorColors = {
        "disk/nvme0n1/read" = colors.blue;
        "disk/nvme0n1/write" = colors.orange;
        "disk/nvme1n1/read" = colors.green;
        "disk/nvme1n1/write" = colors.red;
      };
      sensorLabels = {
        "disk/nvme0n1/read" = "NVMe0 read";
        "disk/nvme0n1/write" = "NVMe0 write";
        "disk/nvme1n1/read" = "NVMe1 read";
        "disk/nvme1n1/write" = "NVMe1 write";
      };
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-disk-device-io";
      title = "SATA/USB Disk I/O";
      ids = [
        "disk/sda/read"
        "disk/sda/write"
        "disk/sdb/read"
        "disk/sdb/write"
        "disk/sdc/read"
        "disk/sdc/write"
      ];
      sensorColors = {
        "disk/sda/read" = colors.blue;
        "disk/sda/write" = colors.orange;
        "disk/sdb/read" = colors.green;
        "disk/sdb/write" = colors.red;
        "disk/sdc/read" = colors.cyan;
        "disk/sdc/write" = colors.purple;
      };
      sensorLabels = {
        "disk/sda/read" = "sda read";
        "disk/sda/write" = "sda write";
        "disk/sdb/read" = "sdb read";
        "disk/sdb/write" = "sdb write";
        "disk/sdc/read" = "sdc read";
        "disk/sdc/write" = "sdc write";
      };
      general = autoGeneral;
    })

    (mkLineFace {
      name = "inspect-network-rates";
      title = "Network Rates";
      ids = networkRateIds;
      sensorColors = {
        "network/all/download" = colors.blue;
        "network/all/upload" = colors.orange;
      };
      sensorLabels = {
        "network/all/download" = "Download";
        "network/all/upload" = "Upload";
      };
      general = autoGeneral;
    })

    (mkTextFace {
      name = "inspect-network-devices";
      title = "Network Devices";
      ids = [
        "network/(?!all).*/download"
        "network/(?!all).*/upload"
        "network/(?!all).*/ipv4address"
        "network/(?!all).*/ipv6address"
        "network/(?!all).*/signal"
      ];
      general = { groupByTotal = true; };
    })

    (mkTextFace {
      name = "inspect-mobo-voltages";
      title = "Motherboard Voltages";
      ids = moboVoltageIds;
      general = { groupByTotal = false; };
    })

    (mkLineFace {
      name = "inspect-ambient-temps";
      title = "ACPI and Wi-Fi Temperatures";
      ids = ambientTempIds;
      sensorColors = {
        "lmsensors/acpitz-acpi-0/temp1" = colors.cyan;
        "lmsensors/iwlwifi_1-virtual-0/temp1" = colors.yellow;
      };
      sensorLabels = {
        "lmsensors/acpitz-acpi-0/temp1" = "ACPI";
        "lmsensors/iwlwifi_1-virtual-0/temp1" = "Wi-Fi";
      };
      general = temperatureGeneral;
    })

    (mkProcessFace {
      name = "inspect-processes";
      title = "Processes";
    })
  ];

  faceNamesForRows = rows:
    lib.unique (lib.concatMap
      (row: map (column: column.face) (row.columns or []))
      rows);

  facesForRows = rows:
    let
      usedFaces = faceNamesForRows rows;
    in
    lib.filterAttrs
      (key: _: lib.any (face: lib.hasPrefix "${face}/" key) usedFaces)
      faces;

  monitorRows = [
    {
      title = "PC Monitoring";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      heightMode = "balanced";
      columns = [
        { face = "Face-monitor-cpu-load"; }
        { face = "Face-monitor-gpu-load"; }
        { face = "Face-monitor-memory"; }
        { face = "Face-monitor-storage"; }
      ];
    }
    {
      heightMode = "balanced";
      columns = [
        { face = "Face-monitor-cpu"; }
        { face = "Face-monitor-gpu-details"; }
        { face = "Face-monitor-memory-details"; }
        { face = "Face-monitor-storage-details"; }
      ];
    }
    {
      heightMode = "balanced";
      columns = [
        { face = "Face-monitor-cooling"; }
        { face = "Face-monitor-grid"; }
        { face = "Face-monitor-network"; }
      ];
    }
  ];

  inspectRows = [
    {
      title = "Compute";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-monitor-cpu-load"; }
        { face = "Face-inspect-cpu-load-history"; }
        { face = "Face-inspect-cpu-temps"; }
        { face = "Face-inspect-cpu-frequency"; }
      ];
    }
    {
      title = "GPU";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-monitor-gpu"; }
        { face = "Face-monitor-gpu-load"; }
        { face = "Face-inspect-gpu-load-history"; }
        { face = "Face-inspect-gpu-power"; }
      ];
    }
    {
      columns = [
        { face = "Face-inspect-gpu-temperature"; }
        { face = "Face-inspect-gpu-frequency"; }
        { face = "Face-inspect-gpu-vram"; }
      ];
    }
    {
      title = "Cooling";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-monitor-cooling"; }
        { face = "Face-inspect-kraken-liquid"; }
        { face = "Face-inspect-kraken-fans"; }
        { face = "Face-inspect-mobo-fans"; }
      ];
    }
    {
      columns = [
        { face = "Face-inspect-grid-rpm"; }
        { face = "Face-inspect-grid-percent"; }
        { face = "Face-inspect-grid-target"; }
      ];
    }
    {
      columns = [
        { face = "Face-inspect-grid-wattage"; }
        { face = "Face-inspect-grid-voltage"; }
      ];
    }
    {
      title = "Memory and Storage";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-inspect-memory"; }
        { face = "Face-inspect-swap"; }
        { face = "Face-inspect-ram-temps"; }
        { face = "Face-inspect-disk-usage"; }
      ];
    }
    {
      columns = [
        { face = "Face-inspect-disk-io"; }
        { face = "Face-inspect-nvme-temps"; }
        { face = "Face-inspect-nvme-io"; }
        { face = "Face-inspect-disk-device-io"; }
      ];
    }
    {
      title = "Network";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-inspect-network-rates"; }
        { face = "Face-inspect-network-devices"; }
      ];
    }
    {
      title = "Board Diagnostics";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-inspect-mobo-temps"; }
        { face = "Face-inspect-ambient-temps"; }
        { face = "Face-inspect-mobo-voltages"; }
      ];
    }
    {
      title = "Processes";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      heightMode = "half";
      columns = [
        {
          face = "Face-inspect-processes";
          noMargins = true;
        }
      ];
    }
    {
      title = "CPU Cores";
      heightMode = "minimum";
      isTitle = true;
    }
    {
      columns = [
        { face = "Face-inspect-core-usage"; }
        { face = "Face-inspect-core-temps"; }
        { face = "Face-inspect-core-frequency"; }
      ];
    }
  ];

  monitorLayout = mkPage {
    title = "Monitor";
    icon = "speedometer";
    rows = monitorRows;
  };

  inspectLayout = mkPage {
    title = "Inspect";
    icon = "preferences-system-performance";
    rows = inspectRows;
  };

in
{
  dataFile = {
    # KDE System Monitor custom pages:
    # ~/.local/share/plasma-systemmonitor/monitor.page
    # ~/.local/share/plasma-systemmonitor/inspect.page
    "plasma-systemmonitor/monitor.page" = (facesForRows monitorRows) // monitorLayout;
    "plasma-systemmonitor/inspect.page" = (facesForRows inspectRows) // inspectLayout;
  };

  inherit customSensorConfigFile;
}
