# Kindle E‑Ink Dashboard

![Python](https://img.shields.io/badge/python-3.9%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Kindle](https://img.shields.io/badge/kindle-9th%20gen%20(KPW3)-lightgrey)

A full‑screen, black‑and‑white dashboard for jailbroken Amazon Kindle e‑readers. Displays the current time, weather, date, and a random quote directly on the e‑ink display via the raw framebuffer — no browser, no app, no bloated dependencies.

## Features

- **Large clock** — 8×8 bitmap font rendered at high scale with AM/PM indicator
- **Weather** — UV index, high/low temperature from [Open‑Meteo](https://open-meteo.com/) (zero API key, zero cost)
- **Battery indicator** — live capacity readout from the kernel sysfs interface
- **Random quotes** — fetched from [Quotable](https://github.com/lukePeavey/quotable) with a local fallback list
- **Auto‑orientation** — detects landscape (800×600) and portrait (600×800) modes
- **Anti‑sleep** — prevents screensaver *and* suspend via `lipc-set-prop`
- **Configurable** — city, coordinates, timezone, refresh rate, battery path in a single JSON file
- **Minimal dependencies** — pure Python, no PIL, no Pillow, no numpy

## Quick start

```bash
# copy to kindle
scp dash.py config.json root@192.168.1.10:/mnt/us/

# edit your location
# then ssh in and run
. /etc/profile
/opt/bin/python3 /mnt/us/dash.py &
```

## Project structure

```
kindle-dashboard/
├── dash.py                  # Main dashboard script
├── config.json              # User configuration
├── fix_fat32_symlinks.sh    # FAT32 workaround for Entware on Kindle
├── .gitignore
└── README.md
```

## Requirements

### Kindle

- Jailbroken Kindle
- [Entware](https://entware.net/) installed on the user store (`/mnt/us`)
- Python ≥ 3.9 from Entware
- Network access (Wi‑Fi) for weather and quote APIs

### Tested on

| Device | Firmware | Works |
|---|---|---|
| Kindle Paperwhite 3 (KPW3) — 9th gen | 5.13.x | ✅ |
| *Your model?* | | [Open an issue](https://github.com/Invictus596/Kindle-Dashboard/issues) |

### Entware setup on Kindle

If you haven't installed Entware yet:

```bash
ssh root@<kindle-ip>
# install Entware using the alternative installer
wget -O - https://raw.githubusercontent.com/Entware/Entware/master/alternative.sh | sh
```

**FAT32 note**: The Kindle user store uses FAT32, which does **not** support symlinks. Entware needs `/opt` pointed at your user store. Run the included helper:

```bash
# copy fix_fat32_symlinks.sh to the kindle first, then:
. /etc/profile
sh /mnt/us/fix_fat32_symlinks.sh
```

Then install Python:

```bash
opkg update
opkg install python3
```

## Installation

### 1. Copy files

```bash
scp dash.py config.json root@<kindle-ip>:/mnt/us/
```

### 2. Configure

Edit `config.json`:

```json
{
  "city": "New York",
  "latitude": 40.7128,
  "longitude": -74.0060,
  "tz_offset_minutes": -300,
  "refresh_interval": 60,
  "battery_path": "/sys/class/power_supply/bd71827_bat/capacity"
}
```

| Key | Description | Example |
|---|---|---|
| `city` | Name displayed on the dashboard | `"New York"` |
| `latitude` / `longitude` | Coordinates for weather data | `40.7128` / `-74.0060` |
| `tz_offset_minutes` | UTC offset in minutes (positive east) | `330` (IST), `-300` (EST) |
| `refresh_interval` | Seconds between screen refreshes | `60` |
| `battery_path` | Sysfs battery capacity node | varies by model (see below) |

**The config file is optional** — the script ships with sensible defaults (Hyderabad, UTC+5:30). Just edit to match your location.

**Battery path** varies by Kindle model:
| Generation | Path |
|---|---|
| 9th gen (KPW3, Oasis 2) | `/sys/class/power_supply/bd71827_bat/capacity` |
| 10th gen (KPW4, Basic) | `/sys/class/power_supply/mx2574_bat/capacity` |
| Other | Run `ls /sys/class/power_supply/` via SSH to find the right node |

### 3. Run

```bash
ssh root@<kindle-ip>
. /etc/profile
/opt/bin/python3 /mnt/us/dash.py &
```

> **Note**: The shebang in `dash.py` points to `/opt/bin/python3.13`. If your Entware Python version differs, either update the shebang or run with the correct path.

To stop: `pkill -f dash.py`

### 4. Auto‑start on boot (optional)

Add to `/etc/rc.local`:

```bash
/opt/bin/python3 /mnt/us/dash.py &
```

Or create an upstart config in `/etc/init.d/` for proper process management.

## How it works

```
┌─────────────┐     ┌──────────┐     ┌──────────┐     ┌───────────┐
│ API calls   │     │ Render   │     │ PNG      │     │ Display   │
│ (weather,   │ ──► │ bitmap   │ ──► │ encode   │ ──► │ via eips  │
│  quote)     │     │ to buf   │     │ to /tmp  │     │ on e-ink  │
└─────────────┘     └──────────┘     └──────────┘     └───────────┘
                          ▲
                          │ time captured here
                          │ (+1s offset for display lag)
```

1. **Data fetch** — weather (Open‑Meteo) and quote (Quotable) are fetched over HTTPS. If either fails, fallback data is used.
2. **Framebuffer detection** — reads `/sys/class/graphics/fb0/virtual_size` and `modes` to determine display dimensions (auto‑detects 800×600 landscape or 600×800 portrait).
3. **Bitmap rendering** — everything is drawn pixel‑by‑pixel into a `bytearray` buffer using a built‑in 8×8 bitmap font table. No external imaging libraries.
4. **PNG encoding** — the raw grayscale buffer is converted to a PNG in memory (zlib + minimal PNG writer, ~30 lines).
5. **Display** — the PNG is written to `/tmp/d.png` and pushed to the framebuffer via Amazon's `eips` utility, then deleted.
6. **Anti‑sleep** — `lipc-set-prop com.lab126.powerd preventSleep 1` re‑asserted every cycle to prevent both screensaver and deep suspend.
7. **Sync** — after each refresh, the script sleeps until the next `:00` second of the minute, keeping the display aligned with the wall clock.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Blank screen | `eips` not found | `which eips` — if missing, your jailbreak may lack it |
| Weather shows `--` | Network unreachable | Check Wi‑Fi; script bypasses SSL verification |
| Battery shows `0` | Wrong `battery_path` | `ls /sys/class/power_supply/` to find the right node |
| Time is wrong | Incorrect `tz_offset_minutes` | IST = `330`, EST = `-300`, CET = `60`, JST = `540` |
| Script exits immediately | Python 3 not found | `opkg install python3` |
| `opkg` fails with "Cannot create symlink" | FAT32 filesystem | Run `fix_fat32_symlinks.sh` to recreate symlinks as file copies |
| Clock lags behind | Display latency | The script compensates with a +1s offset; ≤ 1s error is expected |

## License

MIT
