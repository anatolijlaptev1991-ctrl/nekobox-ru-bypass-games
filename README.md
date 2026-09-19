# NekoBox Route: RU-bypass + Games (with installer)

Routing profile for **NekoRay / NekoBox 4.x** (sing-box core) that proxies
**everything** except Russian resources and games — plus a small installer
that finds your NekoBox installation automatically and installs the profile.

## What it does

| Traffic | Path |
|---|---|
| Russian sites (`.ru`, `.su`, `.рф`, gov, category-ru) | **direct** |
| Riot / Steam / Photon domains (game backends) | **direct** |
| Games by process: LoL (full stack incl. Vanguard), Icarus, PEAK, Phasmophobia | **direct** |
| Google / Gemini / Antigravity, OpenAI, Claude, Grok, Perplexity, Cursor, Windsurf, Kimi, etc. | **proxy** |
| Game launchers' CDN + crash handlers | **direct** |
| Everything else | **proxy** |

DNS: Russian + game domains resolve via your local DNS (nearest servers →
low ping); everything else via DoH through the tunnel. `google.ru` is pinned
to **proxy** (it also matches category-ru — explicit rule wins).

## Install

### Option 1 — installer (recommended)

1. Download `install-routes.ps1` from this repo.
2. Right-click → **Run with PowerShell** (or run from a terminal).

The installer will:

1. **Auto-detect** NekoBox by trying, in order:
   - running `nekobox.exe` process path;
   - `Desktop\vpn.lnk`-style shortcuts (`.lnk` files pointing at nekobox.exe);
   - well-known folders (`Desktop\01_Программы\SOFT\nekoray`, `Desktop\SOFT\nekoray`,
     `Program Files\nekoray`, `%LOCALAPPDATA%\nekoray`, `D:\nekoray`, …);
   - recursive search one level deep on every fixed drive (limited to avoid noise).
2. If nothing is found, **asks you to type the path** to `nekobox.exe`
   (full path or just the folder) — and validates it.
3. Shows what it found, asks for confirmation.
4. **Backs up** any existing route set with the same name into
   `config\_backup_routes\<timestamp>\`.
5. Writes the profile to `config\routes_box\RU-bypass + Games`.
6. Sets it as **active** in `config\groups\nekobox.json`
   (`active_routing`), **only if NekoBox is not running**
   (a running NekoBox overwrites its config on exit).
7. Prints next steps (restart NekoBox / re-dial the tunnel).

### Option 2 — manual

Copy `RU-bypass + Games` (the file, no extension) into:

```
<nekobox folder>\config\routes_box\
```

Then in NekoBox: **Settings → Routes → select "RU-bypass + Games"** → reconnect.

## Files

| File | Purpose |
|---|---|
| `RU-bypass + Games` | the routing profile itself (NekoBox native JSON, no extension) |
| `install-routes.ps1` | auto-finding installer / updater |
| `uninstall-notes.md` | how to remove it cleanly |

## Requirements

- NekoRay / NekoBox **4.x** with sing-box core (tested on 4.0.1 / sing-box 1.9.7-neko-1).
- TUN/VPN mode recommended — process-based rules only make sense there
  (in SOCKS mode the game-process rules do nothing).
- geosite/geoip databases that ship with NekoBox (already included).

## Notes & caveats

- Process rules are implemented via the profile's **custom** JSON —
  NekoRay has no GUI fields for process rules, and custom rules are applied
  **first** (highest priority). This is verified against
  `ConfigBuilder.cpp` (lines 646/647/703-706 of nekoray's source).
- `google.ru` and other `.ru` Google hosts go through **proxy** on purpose.
- This profile does **not** fix Vanguard VAN 68 — if you hit that, see your
  VPN's docs; this profile keeps game traffic on `bypass` (out of the
  proxy chain) but on Windows the TUN adapter still sits in the path.
- Tested by the author on Windows 11 x64, RU region.

## Uninstall

Delete `config\routes_box\RU-bypass + Games` and pick another route set
(or restore from `config\_backup_routes\<timestamp>\`).

## License

MIT — do whatever you want.
