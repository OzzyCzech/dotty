# dotty

A Swift CLI for backing up, restoring, and syncing application config files on macOS.

Two modes:

- **Copy mode** (`backup` / `restore`) — snapshot-based, safe, explicit.
- **Symlink mode** (`link` / `unlink`) — continuous sync via symlinks to a shared location (Dropbox, iCloud, etc.).

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

**Editors & IDEs:** Zed, Visual Studio Code, Cursor, Vim, Neovim
**AI IDEs:** Antigravity, Windsurf, Trae
**AI CLIs & agents:** Claude, Codex CLI, Gemini CLI, Aider, OpenCode, Goose, Crush, Continue, GitHub Copilot
**Terminals:** Terminal, Ghostty, Warp, Alacritty, Kitty, WezTerm
**Shells & prompt:** Bash, Zsh, Fish, Starship, Powerlevel10k, Antidote, tmux
**Git tooling:** Git, GitHub CLI, Lazygit
**Languages & package managers:** npm, Yarn, pnpm, nvm, asdf, Cargo, Ruby, Composer
**DevOps:** AWS CLI, Terraform, Docker
**CLI utilities:** SSH, GnuPG, curl, htop, btop, bat, ripgrep, fd, Ack, yt-dlp
**macOS apps:** Karabiner-Elements, Hammerspoon, AeroSpace
**Other:** Claude, cmux

> Run `dotty list` to see the full list with installation status.

### Security note

Built-in schemas for `aws`, `ssh`, `gnupg`, and `docker` intentionally include **only non-secret config files** — never private keys, credentials, or tokens. If you need to back up sensitive material, do it deliberately via your own `~/.dotty/<id>.json` override and pick a private destination.

## License

MIT — see [LICENSE](LICENSE).
