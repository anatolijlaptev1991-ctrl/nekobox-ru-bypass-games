# Uninstall notes

## Remove the profile

Delete this file from your NekoBox folder:

```
<nekobox folder>\config\routes_box\RU-bypass + Games
```

Then pick another route set in NekoBox (**Settings → Routes**) — or restore
your previous one from:

```
<nekobox folder>\config\_backup_routes\<timestamp>\
```

## If `active_routing` was changed

The installer only changes `active_routing` in
`config\groups\nekobox.json` when NekoBox is **closed**. To revert manually:

1. Open `config\groups\nekobox.json`.
2. Set `"active_routing": "Default"` (or your previous set name).
3. Start NekoBox.

## If you used the installer

The installer only touches two paths:

- `config\routes_box\RU-bypass + Games` (the profile itself)
- `config\groups\nekobox.json` → `active_routing` (only when NekoBox is closed)

It never touches proxies/profiles/servers, subscriptions, or the core.
