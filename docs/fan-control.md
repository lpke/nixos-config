# Fan Control And Cooling Telemetry

Last verified on host `lpnix` on 2026-05-09.

This setup keeps fan control in NixOS config and keeps KDE System Monitor mostly on native KDE sensors. The only custom KDE sensors left are the Grid+ V2 case-fan files.

## Files

- `system/fan-control-config.nix`: fan curves, Grid channel names, Grid sources, smoothing, intervals.
- `system/fan-control.nix`: systemd services, Grid+ V2 daemon, helper scripts, udev rule.
- `user/plasma/apps/system-monitor.nix`: Monitor/Inspect pages and Grid custom sensor config.
- `pkgs/ksystemstats-custom-sensors/default.nix`: simple file-backed KSystemStats plugin.

## What Is Controlled

Controlled:

- NZXT Kraken Z53 pump curve.
- NZXT Kraken Z53 radiator fan curve.
- NZXT Grid+ V2 channels 1 through 6.

Not controlled:

- RTX 3090 GPU AIO pump/fans. Linux monitoring exists, but direct control is not configured.
- Motherboard fan headers.

## What Is Monitored

Native KDE sensors provide CPU, GPU, RAM, NVMe, motherboard, Kraken coolant, and Kraken RPM data.
Some native `lmsensors` IDs use regex patterns in the page config so RAM/Kraken bus renumbering is less likely to create missing sensors after reboot.

Custom Grid+ V2 sensors provide:

- RPM.
- Actual percent reported by the controller.
- Target percent calculated by the curve.
- Voltage.
- Wattage.

Empty Grid channels currently report `0 RPM` and `0 W`. Their percent/voltage can still be non-zero because that is controller output, not proof that a fan is attached.

## Services

### Kraken

`nzxt-kraken-z53-fan-control.service` is a one-shot service. It runs `liquidctl`, writes the pump/radiator curves to the Kraken, then exits. The Kraken firmware applies those curves after that.

Curves are based on coolant temperature, not CPU package temperature.

### Grid+ V2

`nzxt-grid-v2-fan-control.service` is a long-running daemon. Grid+ V2 does not store temperature curves in hardware, so Linux must keep calculating and sending fan targets.

Each loop:

1. Reads CPU package temperature from `coretemp`.
2. Reads Kraken coolant temperature from `z53`.
3. Reads GPU temperature from `nvidia-smi`.
4. Applies configured smoothing.
5. Interpolates each channel curve.
6. Rounds to 5% steps.
7. Writes a new Grid target only when the target changes by at least `hysteresisPercent`.
8. Publishes Grid status files in `/run/nzxt-grid-v2`.

Grid telemetry updates at the same cadence as the control loop. There is no separate telemetry polling daemon now.

### KDE Custom Sensors

The custom KSystemStats plugin is now just a file reader. It reads its upstream config path, `~/.config/customsensorrc`, then exposes the mapped `/run/nzxt-grid-v2` files to KDE System Monitor.

It no longer has adaptive polling, process detection, NVIDIA polling, Kraken polling, or a hardware bridge service.

## Grid Sources

Available Grid source names:

- `cpu_hot`: weighted hot-core temperature: `average(hottest, hottest, second hottest, third hottest)`.
- `cpu_max`: highest raw Intel CPU core/package temperature.
- `gpu`: raw NVIDIA GPU temperature.
- `liquid`: raw Kraken coolant temperature.
- `max_hot`: highest available raw `cpu_hot`, `gpu`, or `liquid`.
- `max_max`: highest available raw `cpu_max`, `gpu`, or `liquid`.
- `cpu_hot_smooth`: smoothed weighted hot-core temperature.
- `cpu_max_smooth`: smoothed highest CPU core/package temperature.
- `gpu_smooth`: smoothed GPU temperature.
- `max_hot_smooth`: highest available `cpu_hot_smooth`, `gpu_smooth`, or raw `liquid`.
- `max_max_smooth`: highest available `cpu_max_smooth`, `gpu_smooth`, or raw `liquid`.

Current intent:

- Front radiator intake channels stay on `liquid`.
- General case airflow channels use `max_max_smooth` or `max_hot_smooth`.

## Smoothing

Smoothing uses an exponential moving average:

```text
next = previous + alpha * (raw - previous)
```

Higher alpha means faster response and less smoothing. Lower alpha means calmer response and more smoothing.

The config has separate rise/fall alpha values per smooth source. Rise alpha should usually be higher than fall alpha so real heat is handled promptly while short spikes settle quietly.

The combined smooth sources are not smoothed a second time. They are calculated as:

```text
max_hot_smooth = max(cpu_hot_smooth, gpu_smooth, liquid)
max_max_smooth = max(cpu_max_smooth, gpu_smooth, liquid)
```

That avoids double-lag and avoids letting one short CPU spike contaminate the combined max signal longer than necessary.

## System Monitor Pages

`Monitor` is the simple overview:

- CPU, GPU, RAM, storage, cooling, case fans, network.
- Native GPU/Kraken sensors only.
- CPU/GPU load shown as pie charts next to text stats.
- Cooling, case fans, and network shown as compact graphs.
- Grid fan values shown as RPM.
- Generated page files are reset before Plasma Manager rewrites them so stale sensor IDs do not linger.

`Inspect` is the detailed page:

- Native CPU/GPU/Kraken/RAM/NVMe/motherboard diagnostics.
- Grid+ V2 actual/target percent, RPM, voltage, and wattage.
- Compact graph rows.

If System Monitor reports missing sensors after a rebuild, restart the KDE stats service:

```bash
systemctl --user restart plasma-ksystemstats.service
```

## Useful Commands

Apply temporarily:

```bash
sudo nixos-rebuild test --flake /home/luke/.config/nixos#lpnix
```

Check services:

```bash
systemctl status nzxt-kraken-z53-fan-control.service
systemctl status nzxt-grid-v2-fan-control.service
```

Check Grid hardware directly:

```bash
nzxt-grid-v2-status
```

Check KDE sensor IDs:

```bash
kstatsviewer --list | rg 'grid_v2|z53|gpu/gpu1|spd5118|nvme'
```

Watch Grid decisions:

```bash
journalctl -u nzxt-grid-v2-fan-control.service -f
```

## Tuning

Quiet idle:

- Lower the low-temperature percent points in Grid/Kraken curves.
- Keep Kraken pump duty conservative; do not push it too low without testing.

Random short spin-ups:

- Use `max_hot_smooth` or `max_max_smooth` instead of raw max sources for case airflow channels.
- Lower `riseAlpha` for more smoothing.
- Raise `hysteresisPercent` only if you are comfortable with larger fan jumps.

More cooling:

- Raise occupied `max_hot_smooth` or `max_max_smooth` Grid channel curves first.
- Raise Kraken radiator fan duty before pushing pump duty much higher.

## Reliability Notes

Fan-control reliability is not reduced by removing custom NVIDIA/Kraken KDE sensors. Kraken firmware control and the Grid daemon still run independently of System Monitor.

Monitoring fidelity is reduced in two places:

- Kraken duty percent is no longer exposed in System Monitor. Native Kraken coolant temp and RPM remain.
- GPU fan percent/RPM is no longer exposed in System Monitor. Native GPU temperature, usage, power, clocks, and VRAM remain.

The Grid daemon still uses `nvidia-smi` for GPU temperature when a channel source needs GPU or a combined max source. If `nvidia-smi` is unavailable, the daemon omits GPU from `max_hot`, `max_max`, `max_hot_smooth`, and `max_max_smooth` for that loop and continues using the remaining available sources.
