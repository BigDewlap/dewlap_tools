# addons-manager

A small script that installs Godot addons from GitHub into your project's `addons/` directory. Supports SHA pinning, local development mode (copy or symlink), and separate runtime/editor addon lists.

## Requirements

- **Python 3.11+**
- **[uv](https://docs.astral.sh/uv/getting-started/installation/)** — the script uses inline script dependencies via `uv run`, so no separate virtualenv setup is needed

## Installation

Copy the `addons-manager/` folder into the root of your Godot project:

```
my-game/
├── project.godot
├── addons/          ← managed by this tool (gitignored)
├── addons-manager/
│   ├── sync_addons.py
│   ├── addons.yaml       ← your config (create from addons.example.yaml)
│   └── addons.lock.json  ← auto-generated, gitignored
```

All commands must be run from the **project root** (the directory containing `project.godot`).

## Setup

Copy the example config and edit it for your project:

```
cp addons-manager/addons.example.yaml addons-manager/addons.yaml
```

Then edit `addons.yaml` to list your addons. See `addons.example.yaml` for all supported fields.

### addons.yaml format

```yaml
runtime:           # installed by sync-dev and sync-prod
  - repo: https://github.com/owner/addon-repo
    ref: "v1.2.3"  # tag, branch, or commit SHA
    source: addons/addon-name   # subfolder inside the repo
    target: addon-name          # folder name to use in your addons/

editor:            # installed by sync-dev only; skipped in sync-prod
  - repo: https://github.com/owner/editor-tool
    ref: "v2.0.0"
    source: addons/editor-tool
    target: editor-tool
```

**`source` + `target`** (recommended): installs a specific subfolder from the repo. The `target` is the folder name created under `addons/`. `target` is required when `source` is set.

**No `source`/`target`** (auto-detect): installs every folder found under `addons/` in the repo archive. No SHA pinning is applied.

## Commands

```powershell
# Install runtime + editor addons (uses local deps when available, downloads otherwise)
uv run addons-manager/sync_addons.py sync-dev

# Install runtime addons only (always downloads from GitHub)
uv run addons-manager/sync_addons.py sync-prod

# Re-resolve refs to latest SHAs and re-download what changed
uv run addons-manager/sync_addons.py update

# Include editor addons in the update
uv run addons-manager/sync_addons.py update --dev

# Show installed vs config refs
uv run addons-manager/sync_addons.py status

# Force re-install everything (ignores lock file)
uv run addons-manager/sync_addons.py sync-dev --force
uv run addons-manager/sync_addons.py sync-prod --force
```

## SHA pinning

When `source`/`target` are specified, `sync_addons.py` resolves the `ref` to a full commit SHA on first install and writes it to `addons.lock.json`. Subsequent runs skip the network call and use the cached SHA to detect staleness.

To update to the latest commit on a branch, run `update` (or `update --dev` for editor addons):

```powershell
uv run addons-manager/sync_addons.py update
```

## Local development mode

If you are actively developing an addon alongside your game, you can have `sync-dev` install from a local clone instead of downloading from GitHub.

1. Add `local_mode: symlink` (or `copy`) to the addon entry in `addons.yaml`.
2. Place a clone of the addon repo at `../<namespace>/<target>/` relative to your project root.
   The namespace defaults to `<project-folder-name>-addons` (e.g. `my-game-addons`).

```
parent/
├── my-game/
│   ├── project.godot
│   └── addons-manager/addons.yaml
└── my-game-addons/
    └── some-addon/     ← local clone; sync-dev installs from here
```

`sync-dev` auto-detects the local clone and installs it instead of downloading. If the clone is absent, it falls back to the GitHub download.

With `local_mode: symlink`, the `addons/<target>` directory is a live symlink into the clone — edits are reflected immediately. With `local_mode: copy` (the default), the directory is copied on each sync.

## .gitignore

The script automatically appends `addons/` and `addons.lock.json` to your `.gitignore` on first run.
