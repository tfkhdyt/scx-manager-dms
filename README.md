# Scx Manager

A [DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) plugin for managing **sched-ext** CPU schedulers through [scxctl](https://github.com/sched-ext/scx-loader) and the `scx_loader` D-Bus service.

Switch schedulers, change performance profiles, and control the loader without leaving Control Center.

## Features

- **Control Center tile** — Shows the active scheduler and profile at a glance
- **Scheduler picker** — Lists schedulers reported by `scxctl list`
- **Profile chips** — Auto, Gaming, Power Save, Low Latency, and Server modes
- **One-click actions** — Start, apply, stop, restart, and restore default
- **Live status** — Polls scheduler state on a configurable interval
- **Custom-args awareness** — Detects schedulers started with custom flags and shows them read-only
- **Auto-hide** — The tile is hidden when `scxctl` is not installed

## Requirements

| Requirement                   | Notes                                          |
| ----------------------------- | ---------------------------------------------- |
| **DankMaterialShell** ≥ 1.2.0 | Declared in `plugin.json` as `requires_dms`    |
| **scxctl**                    | CLI client for `scx_loader`                    |
| **scx_loader**                | D-Bus daemon that manages sched-ext schedulers |
| **sched-ext kernel support**  | A kernel with `CONFIG_SCHED_CLASS_EXT` enabled |

The plugin declares `scxctl` as a dependency in its manifest. The loader daemon must be running for scheduler changes to work.

### Installing scx_loader and scxctl

Install from [crates.io](https://crates.io/) with Rust/cargo:

```bash
cargo install scx_loader scxctl
```

Or build from source: [sched-ext/scx-loader](https://github.com/sched-ext/scx-loader)

Enable and start the loader service:

```bash
sudo systemctl enable --now scx_loader.service
```

Verify the setup:

```bash
command -v scxctl
scxctl list
scxctl get
```

## Installation

1. Copy this directory to your DMS plugins folder:

   ```bash
   cp -r scxManager ~/.config/DankMaterialShell/plugins/
   ```

2. Open **Settings → Plugins**
3. Click **Scan** on Plugin Management section
4. Enable **Scx Manager**
5. Open **Control Center -> Pencil Icon -> Add Widget** and add the `scxManager` widget
6. Resize the tile as needed (50% width or wider shows the expandable detail panel)

## Usage

Open Control Center and locate the **Scheduler** tile (speed icon).

| UI element                | Action                                                        |
| ------------------------- | ------------------------------------------------------------- |
| **Tile subtitle**         | Current scheduler and profile, or "Kernel default" when idle  |
| **Expand (CompoundPill)** | Opens the full control panel                                  |
| **Scheduler dropdown**    | Choose a sched-ext scheduler                                  |
| **Profile chips**         | Select Auto, Gaming, Power Save, Low Latency, or Server       |
| **Start / Apply**         | Start a scheduler or apply scheduler/profile changes          |
| **Stop**                  | Stop the running sched-ext scheduler (returns to EEVDF)       |
| **Restart**               | Restart the current scheduler with its original configuration |
| **Restore default**       | Restore the scheduler configured in `scx_loader`              |
| **Refresh**               | Re-fetch scheduler list and status                            |

### Profiles

Profiles map to `scxctl` modes:

| Profile     | CLI mode     |
| ----------- | ------------ |
| Auto        | `auto`       |
| Gaming      | `gaming`     |
| Power Save  | `powersave`  |
| Low Latency | `lowlatency` |
| Server      | `server`     |

### Custom scheduler arguments

If a scheduler was started outside this plugin with custom arguments (via `scxctl start -a` or `scxctl switch -a`), the plugin shows the active scheduler and flags but disables profile selection and apply. Use `scxctl` directly or **Restore default** to return to managed mode.

## Settings

Configure the polling interval in **Settings → Plugins** — click the **Scx Manager** row to expand its settings (chevron on the right).

| Setting              | Default | Description                               |
| -------------------- | ------- | ----------------------------------------- |
| **Refresh interval** | 5 sec   | How often status is polled (2–60 seconds) |

## Permissions

This plugin requests:

- `settings_read` / `settings_write` — Plugin settings persistence
- `process` — Run `scxctl` commands via the shell

## Troubleshooting

### Tile does not appear

- Confirm `scxctl` is on your `PATH`: `command -v scxctl`
- The plugin checks every 60 seconds; restart DMS or rescan plugins after installing `scxctl`

### "scx_loader not available"

Start the loader service:

```bash
systemctl start scx_loader.service
systemctl status scx_loader.service
```

### Commands fail with permission errors

Configure polkit rules so your user can talk to `org.scx.Loader` without a password prompt.

### Scheduler list is empty

Ensure sched-ext schedulers are installed and registered with `scx_loader`. Check:

```bash
scxctl list
```

### Changes do not stick

Verify the loader configuration in `/etc/scx_loader/` (or your distro’s equivalent) and that no other tool is overriding scheduler state.

## Files

```
scxManager/
├── plugin.json              # Plugin manifest
├── ScxManagerWidget.qml     # Control Center widget
├── ScxManagerSettings.qml   # Plugin settings UI
├── ScxUtils.js              # scxctl output parsing helpers
└── README.md
```

## Related links

- [sched-ext / scx](https://github.com/sched-ext/scx) — sched-ext scheduler collection
- [scx-loader](https://github.com/sched-ext/scx-loader) — `scx_loader` daemon and `scxctl` CLI
- [DMS plugin system docs](https://github.com/AvengeMedia/DankMaterialShell/tree/master/quickshell/PLUGINS) — General plugin development reference

## License

See the repository this plugin is distributed with.
