# dotty

A Swift CLI that wires up macOS dotfiles with symlinks into a destination directory (typically a git repo) so you can version them.

Two operations:

- **`dotty link`** — the main command. Ensures every path declared in your schemas is a symlink from home into the destination directory. Idempotent — figures out from on-disk state what to do (move home file → destination + symlink, or create symlink only, or no-op).
- **`dotty snapshot`** — escape hatch for the rare path that does not symlink well (binary plists, machine-specific configs). Pure copy home → destination; home is untouched.

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
dotty init                  # first-time setup of ~/.dotty/
dotty reinit                # reconfigure: picker preselects current; deselecting removes
dotty reinit --refresh      # also overwrite kept schemas with bundled templates
dotty add zed               # add a single app (copies bundled template)
dotty remove zed            # delete ~/.dotty/zed.json
dotty edit zed              # open ~/.dotty/zed.json in $EDITOR
dotty list                  # configured apps in ~/.dotty/
dotty schemas               # browse bundled schemas
dotty schemas zed           # print one schema's JSON
dotty doctor                # health check

dotty link                  # wire up all configured apps (idempotent)
dotty link zed              # one app
dotty link --dry-run        # preview

dotty snapshot              # plain copy home → destination (no symlinks)
```

`link` is the only operation you typically run. It detects the on-disk state per path:

| home | destination | result |
|---|---|---|
| real file | empty | move home → destination + symlink |
| empty | real file/dir | create symlink → destination |
| symlink → destination | — | no-op (already linked) |
| both populated | — | conflict — rerun with `--prefer home` or `--prefer destination` |

## Configuration

`~/.dotty/` is the single source of truth. After `dotty init`:

```
~/.dotty/
├── config.json     # { "destination": "~/.dotfiles" }
├── zed.json
├── cursor.json
├── ghostty.json
└── …
```

- **`config.json`** holds only the `destination` — the directory where backups live (default `~/.dotty/backup`). That's it.
- **`<id>.json` files** are the schemas dotty acts on. Each one is a complete, editable description of a single app's config paths. Delete a file to drop the app; add one to manage a new app.

Bundled schemas inside the dotty binary are used by `dotty init` / `dotty add` to bootstrap `~/.dotty/`. They are not loaded at runtime — your local files are. Run `dotty schemas` to browse the bundled set without modifying anything.

An app schema:

```json
{
  "name": "My Tool",
  "category": "CLI Utilities",
  "paths": ["~/.config/mytool/conf.toml"]
}
```

### Path mappings (renaming)

By default each path is mirrored — `~/.zshrc` ends up at `<destination>/.zshrc`. To store a source under a renamed location inside the destination (e.g. for an existing `~/.dotfiles` layout that uses different names), use the object form:

```json
{
  "name": "My dotfiles",
  "destination": "~/.dotfiles",
  "paths": [
    "~/.zshrc",
    "~/.p10k.zsh",
    "~/.gitignore",
    { "source": "~/.bin", "target": "bin" },
    { "source": "~/.zsh", "target": "zsh" }
  ]
}
```

`target` is always relative to the destination directory; absolute paths and `..` are rejected at load time. Use the schema-level `destination` to relocate the destination root for this app only.

Then `dotty link dotfiles --dry-run` previews; `dotty link dotfiles` performs the move + symlink. Re-runs are no-ops on already-linked paths.

## Built-in apps

| Category | Apps |
|---|---|
| **Editors** | [Zed](Sources/dotty/Resources/schemas/zed.json) · [Visual Studio Code](Sources/dotty/Resources/schemas/vscode.json) · [Cursor](Sources/dotty/Resources/schemas/cursor.json) · [Vim](Sources/dotty/Resources/schemas/vim.json) · [Neovim](Sources/dotty/Resources/schemas/neovim.json) |
| **AI tools** | [Claude](Sources/dotty/Resources/schemas/claude.json) · [Codex CLI](Sources/dotty/Resources/schemas/codex.json) · [Gemini CLI](Sources/dotty/Resources/schemas/gemini.json) · [Aider](Sources/dotty/Resources/schemas/aider.json) · [OpenCode](Sources/dotty/Resources/schemas/opencode.json) · [Goose](Sources/dotty/Resources/schemas/goose.json) · [Crush](Sources/dotty/Resources/schemas/crush.json) · [Continue](Sources/dotty/Resources/schemas/continue.json) · [GitHub Copilot](Sources/dotty/Resources/schemas/github-copilot.json) · [Antigravity](Sources/dotty/Resources/schemas/antigravity.json) · [Windsurf](Sources/dotty/Resources/schemas/windsurf.json) · [Trae](Sources/dotty/Resources/schemas/trae.json) |
| **Terminals** | [Ghostty](Sources/dotty/Resources/schemas/ghostty.json) · [Warp](Sources/dotty/Resources/schemas/warp.json) · [Alacritty](Sources/dotty/Resources/schemas/alacritty.json) · [Kitty](Sources/dotty/Resources/schemas/kitty.json) · [WezTerm](Sources/dotty/Resources/schemas/wezterm.json) · [cmux](Sources/dotty/Resources/schemas/cmux.json) |
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
