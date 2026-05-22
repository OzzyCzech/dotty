# dotty

A Swift CLI for backing up, restoring, and syncing application config files on macOS.

Each path in a schema declares whether it should live as a **copy** (snapshot) or as a **symlink** to the backup location. Two commands drive everything:

- **`dotty save`** — push current state from home to the backup directory. Copies for copy-mode paths, idempotent symlinks for link-mode paths.
- **`dotty restore`** — apply backup back onto home. Copies for copy-mode paths, ensures symlinks for link-mode paths.

## Install

### Prebuilt universal binary

Direct download: **[dotty-macos-universal.tar.gz](https://github.com/OzzyCzech/dotty/releases/latest/download/dotty-macos-universal.tar.gz)** ([checksum](https://github.com/OzzyCzech/dotty/releases/latest/download/dotty-macos-universal.tar.gz.sha256))

One-liner install:

```sh
curl -L https://github.com/OzzyCzech/dotty/releases/latest/download/dotty-macos-universal.tar.gz \
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
dotty init                              # interactive: pick installed apps to enable
dotty init --yes                        # non-interactive, accept all detected apps
dotty init --destination ~/Dropbox/dot  # skip the destination prompt
dotty list                              # all known apps, grouped
dotty list --installed --compact        # filter + one-line output
dotty doctor                            # report broken links, missing files

dotty save                  # push every installed app's config → backup
dotty save zed              # save a single app
dotty save --dry-run        # preview only

dotty restore               # apply backup to home (prompts per app)
dotty restore zed --force   # no prompts
```

For each path, dotty does the right thing based on its **mode**: copy-mode paths are duplicated to/from the backup directory, link-mode paths are turned into symlinks. Set the mode at the schema level (applies to all paths) or per-path (overrides the schema default).

## Configuration

`~/.dotty/config.json`:

```json
{
  "destination": "~/Dropbox/dotty",
  "disabled": ["vim", "fish"],
  "zed": {
    "paths": ["~/.config/zed/settings.json", "~/.config/zed/keymap.json"]
  },
  "ghostty": {
    "target": "~/iCloud/ghostty-backup"
  }
}
```

- `destination` — global backup root. Default `~/.dotty/backup`.
- `enabled` — whitelist of built-in IDs to keep. When present, every other built-in is hidden. Use this when you want a small, curated set.
- `disabled` — blacklist of built-in IDs to hide. Ignored if `enabled` is also set.
- Either filter only affects built-ins. Explicit overrides here and standalone `~/.dotty/<id>.json` files always show up, so you can mix-and-match with your own additions.
- App key (e.g. `"zed"`) — partial override (paths / target / name).

To add a new app without editing `config.json`, drop `~/.dotty/<id>.json`:

```json
{
  "name": "My Tool",
  "paths": ["~/.config/mytool/conf.toml"]
}
```

### Sync modes

Every path is either a `copy` (snapshot) or a `link` (symlink to the backup). Default is `copy`. Set the mode in three places:

```json
{
  "name": "Roman's dotfiles",
  "mode": "link",                                              // default for the whole schema
  "paths": [
    "~/.zshrc",                                                // inherits schema mode (link)
    { "source": "~/.gitconfig", "mode": "copy" },              // per-path override
    { "source": "~/.bin", "target": "bin" },                   // rename + link
    { "source": "~/.config/zed", "target": "configs/.config/zed", "mode": "copy" }
  ]
}
```

Resolution order: `path.mode` ► `schema.mode` ► `copy`.

### Path mappings (renaming)

By default each path is mirrored — `~/.zshrc` ends up at `<backup>/.zshrc`. To map a source to a renamed location under the backup directory (e.g. for an existing `~/.dotfiles` layout that uses different names), set `target` in the object form. `target` is always relative to the backup directory; absolute paths and `..` are rejected at load time. Use the schema-level `target` field to relocate the entire backup root.

#### Example: wiring dotty into an existing `~/.dotfiles` repo

Drop `~/.dotty/dotfiles.json`:

```json
{
  "name": "My dotfiles",
  "category": "Other",
  "mode": "link",
  "target": "~/.dotfiles",
  "paths": [
    "~/.zshrc",
    "~/.p10k.zsh",
    "~/.gitignore",
    { "source": "~/.bin", "target": "bin" },
    { "source": "~/.zsh", "target": "zsh" },
    { "source": "~/.gitconfig", "mode": "copy" }
  ]
}
```

Then `dotty restore dotfiles --dry-run` previews the result; `dotty restore dotfiles --force` performs it. Existing symlinks pointing at the right target are no-ops.

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
| **CLI utilities** | [SSH](Sources/dotty/Resources/schemas/ssh.json) · [GnuPG](Sources/dotty/Resources/schemas/gnupg.json) · [curl](Sources/dotty/Resources/schemas/curl.json) · [htop](Sources/dotty/Resources/schemas/htop.json) · [btop](Sources/dotty/Resources/schemas/btop.json) · [bat](Sources/dotty/Resources/schemas/bat.json) · [ripgrep](Sources/dotty/Resources/schemas/ripgrep.json) · [fd](Sources/dotty/Resources/schemas/fd.json) · [Ack](Sources/dotty/Resources/schemas/ack.json) · [yt-dlp](Sources/dotty/Resources/schemas/yt-dlp.json) · [dotty](Sources/dotty/Resources/schemas/dotty.json) |
| **macOS apps** | [Karabiner-Elements](Sources/dotty/Resources/schemas/karabiner.json) · [Hammerspoon](Sources/dotty/Resources/schemas/hammerspoon.json) · [AeroSpace](Sources/dotty/Resources/schemas/aerospace.json) |

Run `dotty list` to see the full list with installation status — or `dotty list --installed` / `--missing` / `--user` / `--compact` to filter.

### Security note

Built-in schemas for `aws`, `ssh`, `gnupg`, and `docker` intentionally include **only non-secret config files** — never private keys, credentials, or tokens. If you need to back up sensitive material, do it deliberately via your own `~/.dotty/<id>.json` override and pick a private destination.

## License

MIT — see [LICENSE](LICENSE).
