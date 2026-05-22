# dotty

A Swift CLI for backing up, restoring, and syncing application config files on macOS.

Two modes:

- **Copy mode** (`backup` / `restore`) — snapshot-based, safe, explicit.
- **Symlink mode** (`link` / `unlink`) — mackup-style continuous sync via symlinks to a shared location (Dropbox, iCloud, etc.).

## Install

```sh
git clone https://github.com/OzzyCzech/dotty.git
cd dotty
swift build -c release
cp .build/release/dotty /usr/local/bin/
```

## Usage

```sh
dotty init                  # create ~/.dotty/config.json
dotty list                  # show all known apps
dotty doctor                # report config health

dotty backup                # back up all installed apps
dotty backup zed            # back up a single app
dotty backup --dry-run      # preview only

dotty restore               # prompts per app
dotty restore zed --force   # no prompts

dotty link zed              # move source → backup, symlink in place
dotty unlink zed            # replace symlink with real copy
```

## Configuration

`~/.dotty/config.json`:

```json
{
  "destination": "~/Dropbox/dotty",
  "zed": {
    "paths": ["~/.config/zed/settings.json", "~/.config/zed/keymap.json"]
  },
  "ghostty": {
    "target": "~/iCloud/ghostty-backup"
  }
}
```

To add a new app without editing `config.json`, drop `~/.dotty/<id>.json`:

```json
{
  "name": "My Tool",
  "paths": ["~/.config/mytool/conf.toml"]
}
```

### Schema priority (highest first)

1. `~/.dotty/<id>.json` — standalone, full replacement.
2. App entry in `~/.dotty/config.json` — partial override (paths / target).
3. Bundled built-in JSON inside the binary.

## Built-in apps

Zed, Visual Studio Code, Cursor, Terminal, Ghostty, yt-dlp, Ack, Claude, Warp.

## License

MIT — see [LICENSE](LICENSE).
