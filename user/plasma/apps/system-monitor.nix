{ lib }:

let
  raw = value: {
    inherit value;
    escapeValue = false;
  };

  sensorList = ids:
    raw "[${lib.concatMapStringsSep "," (id: ''"${id}"'') ids}]";

  lineChartSettings = {
    historyAmount = 300;
    lineChartFillOpacity = 15;
    lineChartSmooth = false;
    showGridLines = true;
    showYAxisLabels = true;
  };

  percentTempLineChartSettings = lineChartSettings // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 100;
  };

  cpuFrequencyLineChartSettings = lineChartSettings // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 6000;
  };

  gpuFrequencyLineChartSettings = lineChartSettings // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 10000;
  };

  autoLineChartSettings = lineChartSettings // {
    rangeAutoY = true;
  };

  fanLineChartSettings = lineChartSettings // {
    rangeAutoY = false;
    rangeFromY = 0;
    rangeToY = 4000;
  };

  layoutKeys = [
    "page"
    "page/row-0"
    "page/row-1"
    "page/row-1/column-0"
    "page/row-1/column-0/section-0"
    "page/row-1/column-1"
    "page/row-1/column-1/section-0"
    "page/row-1/column-2"
    "page/row-1/column-2/section-0"
    "page/row-2"
    "page/row-2/column-0"
    "page/row-2/column-0/section-0"
    "page/row-2/column-1"
    "page/row-2/column-1/section-0"
    "page/row-2/column-2"
    "page/row-2/column-2/section-0"
    "page/row-3"
    "page/row-4"
    "page/row-4/column-0"
    "page/row-4/column-0/section-0"
    "page/row-4/column-1"
    "page/row-4/column-1/section-0"
    "page/row-5"
    "page/row-5/column-0"
    "page/row-5/column-0/section-0"
    "page/row-5/column-1"
    "page/row-5/column-1/section-0"
    "page/row-5/column-2"
    "page/row-5/column-2/section-0"
    "page/row-6"
    "page/row-7"
    "page/row-7/column-0"
    "page/row-7/column-0/section-0"
    "page/row-7/column-1"
    "page/row-7/column-1/section-0"
    "page/row-8"
    "page/row-9"
    "page/row-9/column-0"
    "page/row-9/column-0/section-0"
    "page/row-9/column-1"
    "page/row-9/column-1/section-0"
  ];

  monitorLayout = {
    page = {
      Title = "Monitor";
      actionsFace = "";
      icon = "utilities-system-monitor";
      loadType = "onstart";
      margin = 2;
      version = 1;
    };

    "page/row-0" = {
      Title = "CPU";
      heightMode = "minimum";
      isTitle = true;
      name = "row-0";
    };
    "page/row-1" = {
      heightMode = "balanced";
      isTitle = false;
      name = "row-1";
    };
    "page/row-1/column-0" = {
      name = "column-0";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-0/section-0" = {
      face = "Face-hw-cpu-usage";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-1/column-1" = {
      name = "column-1";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-1/section-0" = {
      face = "Face-hw-cpu";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-1/column-2" = {
      name = "column-2";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-2/section-0" = {
      face = "Face-hw-cpu-usage-history";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-1/column-3" = {
      name = "column-3";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-3/section-0" = {
      face = "Face-hw-cpu-frequency";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-1/column-4" = {
      name = "column-4";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-4/section-0" = {
      face = "Face-hw-kraken";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-1/column-5" = {
      name = "column-5";
      noMargins = false;
      showBackground = true;
    };
    "page/row-1/column-5/section-0" = {
      face = "Face-hw-misc-fans";
      isSeparator = false;
      name = "section-0";
    };

    "page/row-2" = {
      Title = "GPU";
      heightMode = "minimum";
      isTitle = true;
      name = "row-2";
    };
    "page/row-3" = {
      heightMode = "balanced";
      isTitle = false;
      name = "row-3";
    };
    "page/row-3/column-0" = {
      name = "column-0";
      noMargins = false;
      showBackground = true;
    };
    "page/row-3/column-0/section-0" = {
      face = "Face-hw-gpu-usage";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-3/column-1" = {
      name = "column-1";
      noMargins = false;
      showBackground = true;
    };
    "page/row-3/column-1/section-0" = {
      face = "Face-hw-gpu";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-3/column-2" = {
      name = "column-2";
      noMargins = false;
      showBackground = true;
    };
    "page/row-3/column-2/section-0" = {
      face = "Face-hw-gpu-usage-history";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-3/column-3" = {
      name = "column-3";
      noMargins = false;
      showBackground = true;
    };
    "page/row-3/column-3/section-0" = {
      face = "Face-hw-gpu-frequency";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-3/column-4" = {
      name = "column-4";
      noMargins = false;
      showBackground = true;
    };
    "page/row-3/column-4/section-0" = {
      face = "Face-hw-gpu-vram";
      isSeparator = false;
      name = "section-0";
    };

    "page/row-4" = {
      Title = "Memory and Storage";
      heightMode = "minimum";
      isTitle = true;
      name = "row-4";
    };
    "page/row-5" = {
      heightMode = "balanced";
      isTitle = false;
      name = "row-5";
    };
    "page/row-5/column-0" = {
      name = "column-0";
      noMargins = false;
      showBackground = true;
    };
    "page/row-5/column-0/section-0" = {
      face = "Face-hw-memory";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-5/column-1" = {
      name = "column-1";
      noMargins = false;
      showBackground = true;
    };
    "page/row-5/column-1/section-0" = {
      face = "Face-hw-disks";
      isSeparator = false;
      name = "section-0";
    };

    "page/row-6" = {
      Title = "Temperatures";
      heightMode = "minimum";
      isTitle = true;
      name = "row-6";
    };
    "page/row-7" = {
      heightMode = "balanced";
      isTitle = false;
      name = "row-7";
    };
    "page/row-7/column-0" = {
      name = "column-0";
      noMargins = false;
      showBackground = true;
    };
    "page/row-7/column-0/section-0" = {
      face = "Face-hw-ram-temps";
      isSeparator = false;
      name = "section-0";
    };
    "page/row-7/column-1" = {
      name = "column-1";
      noMargins = false;
      showBackground = true;
    };
    "page/row-7/column-1/section-0" = {
      face = "Face-hw-ssd-temps";
      isSeparator = false;
      name = "section-0";
    };
  };

in
let
  hardwarePage = {
      "Face-hw-cpu/Appearance" = {
        Title = "CPU Temperatures";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-cpu/SensorColors" = {
        "cpu/all/averageTemperature" = "233,120,61";
        "cpu/all/maximumTemperature" = "233,61,97";
      };
      "Face-hw-cpu/SensorLabels" = {
        "cpu/all/averageTemperature" = "Avg Temp";
        "cpu/all/maximumTemperature" = "Max Temp";
      };
      "Face-hw-cpu/Sensors" = {
        highPrioritySensorIds = sensorList [
          "cpu/all/averageTemperature"
          "cpu/all/maximumTemperature"
        ];
      };
      "Face-hw-cpu/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-cpu-usage/Appearance" = {
        Title = "CPU";
        chartFace = "org.kde.ksysguard.piechart";
      };
      "Face-hw-cpu-usage/SensorColors" = {
        "cpu/all/usage" = "61,174,233";
      };
      "Face-hw-cpu-usage/Sensors" = {
        highPrioritySensorIds = sensorList [
          "cpu/all/usage"
        ];
        totalSensors = sensorList [
          "cpu/all/usage"
        ];
      };
      "Face-hw-cpu-usage/org.kde.ksysguard.piechart/General" = {
        showLegend = false;
      };

      "Face-hw-cpu-usage-history/Appearance" = {
        Title = "CPU Usage";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-cpu-usage-history/SensorColors" = {
        "cpu/all/usage" = "61,174,233";
      };
      "Face-hw-cpu-usage-history/Sensors" = {
        highPrioritySensorIds = sensorList [
          "cpu/all/usage"
        ];
      };
      "Face-hw-cpu-usage-history/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-cpu-frequency/Appearance" = {
        Title = "CPU Frequency";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-cpu-frequency/SensorColors" = {
        "cpu/all/averageFrequency" = "61,174,233";
        "cpu/all/maximumFrequency" = "233,120,61";
      };
      "Face-hw-cpu-frequency/SensorLabels" = {
        "cpu/all/averageFrequency" = "Avg Frequency";
        "cpu/all/maximumFrequency" = "Max Frequency";
      };
      "Face-hw-cpu-frequency/Sensors" = {
        highPrioritySensorIds = sensorList [
          "cpu/all/averageFrequency"
          "cpu/all/maximumFrequency"
        ];
      };
      "Face-hw-cpu-frequency/org.kde.ksysguard.linechart/General" = cpuFrequencyLineChartSettings;

      "Face-hw-gpu/Appearance" = {
        Title = "GPU Temperature";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-gpu/SensorColors" = {
        "gpu/gpu1/temperature" = "233,120,61";
      };
      "Face-hw-gpu/SensorLabels" = {
        "gpu/gpu1/temperature" = "Temp";
      };
      "Face-hw-gpu/Sensors" = {
        highPrioritySensorIds = sensorList [
          "gpu/gpu1/temperature"
        ];
      };
      "Face-hw-gpu/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-gpu-usage/Appearance" = {
        Title = "GPU";
        chartFace = "org.kde.ksysguard.piechart";
      };
      "Face-hw-gpu-usage/SensorColors" = {
        "gpu/gpu1/usage" = "106,190,48";
      };
      "Face-hw-gpu-usage/Sensors" = {
        highPrioritySensorIds = sensorList [
          "gpu/gpu1/usage"
        ];
        totalSensors = sensorList [
          "gpu/gpu1/usage"
        ];
      };
      "Face-hw-gpu-usage/org.kde.ksysguard.piechart/General" = {
        showLegend = false;
      };

      "Face-hw-gpu-usage-history/Appearance" = {
        Title = "GPU Usage";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-gpu-usage-history/SensorColors" = {
        "gpu/gpu1/usage" = "106,190,48";
      };
      "Face-hw-gpu-usage-history/Sensors" = {
        highPrioritySensorIds = sensorList [
          "gpu/gpu1/usage"
        ];
      };
      "Face-hw-gpu-usage-history/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-gpu-frequency/Appearance" = {
        Title = "GPU Frequencies";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-gpu-frequency/SensorColors" = {
        "gpu/gpu1/coreFrequency" = "61,174,233";
        "gpu/gpu1/memoryFrequency" = "180,140,255";
      };
      "Face-hw-gpu-frequency/SensorLabels" = {
        "gpu/gpu1/coreFrequency" = "Core";
        "gpu/gpu1/memoryFrequency" = "Memory";
      };
      "Face-hw-gpu-frequency/Sensors" = {
        highPrioritySensorIds = sensorList [
          "gpu/gpu1/coreFrequency"
          "gpu/gpu1/memoryFrequency"
        ];
      };
      "Face-hw-gpu-frequency/org.kde.ksysguard.linechart/General" = gpuFrequencyLineChartSettings;

      "Face-hw-gpu-vram/Appearance" = {
        Title = "GPU VRAM";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-gpu-vram/SensorColors" = {
        "gpu/gpu1/usedVram" = "180,140,255";
      };
      "Face-hw-gpu-vram/SensorLabels" = {
        "gpu/gpu1/usedVram" = "Used";
      };
      "Face-hw-gpu-vram/Sensors" = {
        highPrioritySensorIds = sensorList [
          "gpu/gpu1/usedVram"
        ];
        lowPrioritySensorIds = sensorList [
          "gpu/gpu1/totalVram"
        ];
      };
      "Face-hw-gpu-vram/org.kde.ksysguard.linechart/General" = autoLineChartSettings;

      "Face-hw-memory/Appearance" = {
        Title = "RAM Usage";
        chartFace = "org.kde.ksysguard.piechart";
      };
      "Face-hw-memory/SensorColors" = {
        "memory/physical/used" = "61,174,233";
      };
      "Face-hw-memory/Sensors" = {
        highPrioritySensorIds = sensorList [
          "memory/physical/used"
        ];
        lowPrioritySensorIds = sensorList [
          "memory/physical/usedPercent"
          "memory/physical/application"
          "memory/physical/cache"
          "memory/physical/free"
        ];
        totalSensors = sensorList [
          "memory/physical/used"
          "memory/physical/total"
        ];
      };
      "Face-hw-memory/org.kde.ksysguard.piechart/General" = {
        showLegend = true;
      };

      "Face-hw-disks/Appearance" = {
        Title = "SSD Usage";
        chartFace = "org.kde.ksysguard.horizontalbars";
      };
      "Face-hw-disks/SensorColors" = {
        "disk/all/usedPercent" = "61,174,233";
        "disk/(?!all).*/usedPercent" = "106,190,48";
      };
      "Face-hw-disks/SensorLabels" = {
        "disk/all/usedPercent" = "All Disks";
        "disk/(?!all).*/usedPercent" = "Mounted Volumes";
      };
      "Face-hw-disks/Sensors" = {
        highPrioritySensorIds = sensorList [
          "disk/all/usedPercent"
          "disk/(?!all).*/usedPercent"
        ];
        lowPrioritySensorIds = sensorList [
          "disk/nvme0n1/read"
          "disk/nvme0n1/write"
          "disk/nvme1n1/read"
          "disk/nvme1n1/write"
        ];
      };

      "Face-hw-ram-temps/Appearance" = {
        Title = "RAM Temperatures";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-ram-temps/SensorColors" = {
        "lmsensors/spd5118-i2c-3-50/temp1" = "61,174,233";
        "lmsensors/spd5118-i2c-3-51/temp1" = "106,190,48";
        "lmsensors/spd5118-i2c-3-52/temp1" = "233,120,61";
        "lmsensors/spd5118-i2c-3-53/temp1" = "180,140,255";
      };
      "Face-hw-ram-temps/SensorLabels" = {
        "lmsensors/spd5118-i2c-3-50/temp1" = "DIMM 1";
        "lmsensors/spd5118-i2c-3-51/temp1" = "DIMM 2";
        "lmsensors/spd5118-i2c-3-52/temp1" = "DIMM 3";
        "lmsensors/spd5118-i2c-3-53/temp1" = "DIMM 4";
      };
      "Face-hw-ram-temps/Sensors" = {
        highPrioritySensorIds = sensorList [
          "lmsensors/spd5118-i2c-3-50/temp1"
          "lmsensors/spd5118-i2c-3-51/temp1"
          "lmsensors/spd5118-i2c-3-52/temp1"
          "lmsensors/spd5118-i2c-3-53/temp1"
        ];
      };
      "Face-hw-ram-temps/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-ssd-temps/Appearance" = {
        Title = "SSD Temperatures";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-ssd-temps/SensorColors" = {
        "lmsensors/nvme-pci-0200/temp1" = "61,174,233";
        "lmsensors/nvme-pci-0200/temp3" = "233,120,61";
        "lmsensors/nvme-pci-7100/temp1" = "106,190,48";
        "lmsensors/nvme-pci-7100/temp2" = "180,140,255";
        "lmsensors/nvme-pci-7100/temp3" = "233,61,97";
      };
      "Face-hw-ssd-temps/SensorLabels" = {
        "lmsensors/nvme-pci-0200/temp1" = "NVMe 0200 Composite";
        "lmsensors/nvme-pci-0200/temp3" = "NVMe 0200 Sensor 2";
        "lmsensors/nvme-pci-7100/temp1" = "NVMe 7100 Composite";
        "lmsensors/nvme-pci-7100/temp2" = "NVMe 7100 Sensor 1";
        "lmsensors/nvme-pci-7100/temp3" = "NVMe 7100 Sensor 2";
      };
      "Face-hw-ssd-temps/Sensors" = {
        highPrioritySensorIds = sensorList [
          "lmsensors/nvme-pci-0200/temp1"
          "lmsensors/nvme-pci-0200/temp3"
          "lmsensors/nvme-pci-7100/temp1"
          "lmsensors/nvme-pci-7100/temp2"
          "lmsensors/nvme-pci-7100/temp3"
        ];
      };
      "Face-hw-ssd-temps/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-kraken/Appearance" = {
        Title = "NZXT Kraken";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-kraken/SensorColors" = {
        "lmsensors/z53-hid-3-7/temp1" = "61,174,233";
      };
      "Face-hw-kraken/SensorLabels" = {
        "lmsensors/z53-hid-3-7/temp1" = "Coolant";
      };
      "Face-hw-kraken/Sensors" = {
        highPrioritySensorIds = sensorList [
          "lmsensors/z53-hid-3-7/temp1"
        ];
      };
      "Face-hw-kraken/org.kde.ksysguard.linechart/General" = percentTempLineChartSettings;

      "Face-hw-misc-fans/Appearance" = {
        Title = "Fan Speeds";
        chartFace = "org.kde.ksysguard.linechart";
      };
      "Face-hw-misc-fans/SensorColors" = {
        "lmsensors/z53-hid-3-7/fan1" = "106,190,48";
        "lmsensors/z53-hid-3-7/fan2" = "233,120,61";
      };
      "Face-hw-misc-fans/SensorLabels" = {
        "lmsensors/z53-hid-3-7/fan1" = "Pump";
        "lmsensors/z53-hid-3-7/fan2" = "Radiator Fan";
      };
      "Face-hw-misc-fans/Sensors" = {
        highPrioritySensorIds = sensorList [
          "lmsensors/z53-hid-3-7/fan1"
          "lmsensors/z53-hid-3-7/fan2"
        ];
      };
      "Face-hw-misc-fans/org.kde.ksysguard.linechart/General" = fanLineChartSettings;

      page = {
        Title = "Hardware";
        actionsFace = "";
        icon = "preferences-devices-cpu";
        loadType = "onstart";
        margin = 2;
        version = 1;
      };

      "page/row-0" = {
        Title = "Compute";
        heightMode = "minimum";
        isTitle = true;
        name = "row-0";
      };
      "page/row-1" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-1";
      };
      "page/row-1/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-1/column-0/section-0" = {
        face = "Face-hw-cpu-usage";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-1/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-1/column-1/section-0" = {
        face = "Face-hw-cpu-usage-history";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-1/column-2" = {
        name = "column-2";
        noMargins = false;
        showBackground = true;
      };
      "page/row-1/column-2/section-0" = {
        face = "Face-hw-kraken";
        isSeparator = false;
        name = "section-0";
      };

      "page/row-2" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-2";
      };
      "page/row-2/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-2/column-0/section-0" = {
        face = "Face-hw-cpu";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-2/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-2/column-1/section-0" = {
        face = "Face-hw-cpu-frequency";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-2/column-2" = {
        name = "column-2";
        noMargins = false;
        showBackground = true;
      };
      "page/row-2/column-2/section-0" = {
        face = "Face-hw-misc-fans";
        isSeparator = false;
        name = "section-0";
      };

      "page/row-3" = {
        Title = "GPU";
        heightMode = "minimum";
        isTitle = true;
        name = "row-3";
      };
      "page/row-4" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-4";
      };
      "page/row-4/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-4/column-0/section-0" = {
        face = "Face-hw-gpu-usage";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-4/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-4/column-1/section-0" = {
        face = "Face-hw-gpu-usage-history";
        isSeparator = false;
        name = "section-0";
      };

      "page/row-5" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-5";
      };
      "page/row-5/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-5/column-0/section-0" = {
        face = "Face-hw-gpu";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-5/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-5/column-1/section-0" = {
        face = "Face-hw-gpu-frequency";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-5/column-2" = {
        name = "column-2";
        noMargins = false;
        showBackground = true;
      };
      "page/row-5/column-2/section-0" = {
        face = "Face-hw-gpu-vram";
        isSeparator = false;
        name = "section-0";
      };

      "page/row-6" = {
        Title = "Memory and Storage";
        heightMode = "minimum";
        isTitle = true;
        name = "row-6";
      };
      "page/row-7" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-7";
      };
      "page/row-7/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-7/column-0/section-0" = {
        face = "Face-hw-memory";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-7/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-7/column-1/section-0" = {
        face = "Face-hw-disks";
        isSeparator = false;
        name = "section-0";
      };

      "page/row-8" = {
        Title = "Temperatures";
        heightMode = "minimum";
        isTitle = true;
        name = "row-8";
      };
      "page/row-9" = {
        heightMode = "balanced";
        isTitle = false;
        name = "row-9";
      };
      "page/row-9/column-0" = {
        name = "column-0";
        noMargins = false;
        showBackground = true;
      };
      "page/row-9/column-0/section-0" = {
        face = "Face-hw-ram-temps";
        isSeparator = false;
        name = "section-0";
      };
      "page/row-9/column-1" = {
        name = "column-1";
        noMargins = false;
        showBackground = true;
      };
      "page/row-9/column-1/section-0" = {
        face = "Face-hw-ssd-temps";
        isSeparator = false;
        name = "section-0";
      };
  };
in
{
  dataFile = {
    # KDE System Monitor custom pages:
    # ~/.local/share/plasma-systemmonitor/hardware.page
    # ~/.local/share/plasma-systemmonitor/monitor.page
    "plasma-systemmonitor/hardware.page" = hardwarePage;
    "plasma-systemmonitor/monitor.page" = (builtins.removeAttrs hardwarePage layoutKeys) // monitorLayout;
  };
}
