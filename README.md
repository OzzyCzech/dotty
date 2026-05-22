# dotty

A Swift CLI for backing up, restoring, and syncing application config files on macOS.

Two modes:

- **Copy mode** (`backup` / `restore`) — snapshot-based, safe, explicit.
- **Symlink mode** (`link` / `unlink`) — continuous sync via symlinks to a shared location (Dropbox, iCloud, etc.).

## Install

### Prebuilt universal binary

Download the latest release and drop the binary on your `PATH`:

```sh
VERSION=$(curl -s https://api.github.com/repos/OzzyCzech/dotty/releases/latest | grep tag_name | cut -d '"' -f4)
curl -L "https://github.com/OzzyCzech/dotty/releases/download/${VERSION}/dotty-${VERSION#v}-macos-universal.tar.gz" \
  | tar -xz -C /usr/local/bin
xattr -d com.apple.quarantine /usr/local/bin/dotty 2>/dev/null || true
dotty --version
```

The binary is universal (Apple Silicon + Intel). It is not yet signed, so the `xattr` line strips the Gatekeeper quarantine flag — drop it once the project is signed and notarized.

### Build from source

```sh
git clone https://github.com/OzzyCzech/dotty.git
cd dotty
swift build -c release
cp .build/release/dotty /usr/local/bin/
```

## Usage

```sh
dotty init                              # create ~/.dotty/config.json
dotty init --destination ~/Dropbox/dot  # custom backup root
dotty list                              # all known apps, grouped
dotty list --installed --compact        # filter + one-line output
dotty doctor                            # report broken links, missing files

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

### Path mappings (renaming)

By default each path is mirrored — `~/.zshrc` ends up at `<backup>/.zshrc`. To map a source to a renamed location under the backup directory (e.g. for an existing `~/.dotfiles` layout that uses different names), use the object form:

```json
{
  "name": "My dotfiles",
  "paths": [
    "~/.zshrc",
    { "source": "~/.bin", "target": "bin" },
    { "source": "~/.config", "target": "configs/.config" }
  ]
}
```

`target` is always relative to the backup directory; absolute paths and `..` are rejected at load time. Use the schema-level `target` field to relocate the entire backup root.

#### Example: wiring dotty into an existing `~/.dotfiles` repo

Drop `~/.dotty/dotfiles.json`:

```json
{
  "name": "My dotfiles",
  "target": "~/.dotfiles",
  "paths": [
    "~/.zshrc",
    "~/.p10k.zsh",
    "~/.gitignore",
    { "source": "~/.bin", "target": "bin" },
    { "source": "~/.zsh", "target": "zsh" }
  ]
}
```

Then `dotty link dotfiles --dry-run` previews the symlinks; `dotty link dotfiles` performs them (existing symlinks pointing at the right target are no-ops).

### Schema priority (highest first)

1. `~/.dotty/<id>.json` — standalone, full replacement.
2. App entry in `~/.dotty/config.json` — partial override (paths / target).
3. Bundled built-in JSON inside the binary.

## Built-in apps

| Category | Apps |
|---|---|
| **Editors** | [Zed](Sources/dotty/Resources/schemas/zed.json) · [Visual Studio Code](Sources/dotty/Resources/schemas/vscode.json) · [Cursor](Sources/dotty/Resources/schemas/cursor.json) · [Vim](Sources/dotty/Resources/schemas/vim.json) · [Neovim](Sources/dotty/Resources/schemas/neovim.json) |
| **AI tools** | [Claude](Sources/dotty/Resources/schemas/claude.json) · [Codex CLI](Sources/dotty/Resources/schemas/codex.json) · [Gemini CLI](Sources/dotty/Resources/schemas/gemini.json) · [Aider](Sources/dotty/Resources/schemas/aider.json) · [OpenCode](Sources/dotty/Resources/schemas/opencode.json) · [Goose](Sources/dotty/Resources/schemas/goose.json) · [Crush](Sources/dotty/Resources/schemas/crush.json) · [Continue](Sources/dotty/Resources/schemas/continue.json) · [GitHub Copilot](Sources/dotty/Resources/schemas/github-copilot.json) · [Antigravity](Sources/dotty/Resources/schemas/antigravity.json) · [Windsurf](Sources/dotty/Resources/schemas/windsurf.json) · [Trae](Sources/dotty/Resources/schemas/trae.json) |
| **Terminals** | [Terminal](Sources/dotty/Resources/schemas/terminal.json) · [Ghostty](Sources/dotty/Resources/schemas/ghostty.json) · [Warp](Sources/dotty/Resources/schemas/warp.json) · [Alacritty](Sources/dotty/Resources/schemas/alacritty.json) · [Kitty](Sources/dotty/Resources/schemas/kitty.json) · [WezTerm](Sources/dotty/Resources/schemas/wezterm.json) · [cmux](Sources/dotty/Resources/schemas/cmux.json) |
| **Shell & prompt** | [Bash](Sources/dotty/Resources/schemas/bash.json) · [Zsh](Sources/dotty/Resources/schemas/zsh.json) · [Fish](Sources/dotty/Resources/schemas/fish.json) · [tmux](Sources/dotty/Resources/schemas/tmux.json) · [Starship](Sources/dotty/Resources/schemas/starship.json) · [Powerlevel10k](Sources/dotty/Resources/schemas/powerlevel10k.json) · [Antidote](Sources/dotty/Resources/schemas/antidote.json) |
| **Git** | [Git](Sources/dotty/Resources/schemas/git.json) · [GitHub CLI](Sources/dotty/Resources/schemas/gh.json) · [Lazygit](Sources/dotty/Resources/schemas/lazygit.json) |
| **Languages** | [npm](Sources/dotty/Resources/schemas/npm.json) · [Yarn](Sources/dotty/Resources/schemas/yarn.json) · [pnpm](Sources/dotty/Resources/schemas/pnpm.json) · [nvm](Sources/dotty/Resources/schemas/nvm.json) · [asdf](Sources/dotty/Resources/schemas/asdf.json) · [Cargo](Sources/dotty/Resources/schemas/cargo.json) · [Ruby](Sources/dotty/Resources/schemas/ruby.json) · [Composer](Sources/dotty/Resources/schemas/composer.json) |
| **DevOps** | [AWS CLI](Sources/dotty/Resources/schemas/aws.json) · [Terraform](Sources/dotty/Resources/schemas/terraform.json) · [Docker](Sources/dotty/Resources/schemas/docker.json) |
| **CLI utilities** | [SSH](Sources/dotty/Resources/schemas/ssh.json) · [GnuPG](Sources/dotty/Resources/schemas/gnupg.json) · [curl](Sources/dotty/Resources/schemas/curl.json) · [htop](Sources/dotty/Resources/schemas/htop.json) · [btop](Sources/dotty/Resources/schemas/btop.json) · [bat](Sources/dotty/Resources/schemas/bat.json) · [ripgrep](Sources/dotty/Resources/schemas/ripgrep.json) · [fd](Sources/dotty/Resources/schemas/fd.json) · [Ack](Sources/dotty/Resources/schemas/ack.json) · [yt-dlp](Sources/dotty/Resources/schemas/yt-dlp.json) |
| **macOS apps** | [Karabiner-Elements](Sources/dotty/Resources/schemas/karabiner.json) · [Hammerspoon](Sources/dotty/Resources/schemas/hammerspoon.json) · [AeroSpace](Sources/dotty/Resources/schemas/aerospace.json) |

Run `dotty list` to see the full list with installation status — or `dotty list --installed` / `--missing` / `--user` / `--compact` to filter.

### Security note

Built-in schemas for `aws`, `ssh`, `gnupg`, and `docker` intentionally include **only non-secret config files** — never private keys, credentials, or tokens. If you need to back up sensitive material, do it deliberately via your own `~/.dotty/<id>.json` override and pick a private destination.

## License

MIT — see [LICENSE](LICENSE).
