#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "PyYAML>=6.0",
#   "requests>=2.31",
# ]
# ///

from __future__ import annotations

import sys
sys.dont_write_bytecode = True

import argparse
import json
import os
import shutil
import subprocess
import tempfile
import zipfile
from dataclasses import dataclass, field
from pathlib import Path
from typing import Literal, Optional

import requests
import yaml

SCRIPT_DIR = Path(__file__).parent
ADDONS_DIR = Path("addons")
LOCKFILE = SCRIPT_DIR / "addons.lock.json"
CONFIG_FILE = SCRIPT_DIR / "addons.yaml"
GITIGNORE = Path(".gitignore")

LocalMode = Literal["copy", "symlink"]

# Lock entry shapes:
#   remote install: {"ref": str, "sha": str}
#   local install:  {"local": str, "mode": str}


@dataclass
class Addon:
    repo: str
    ref: str
    source: Optional[str] = None
    target: Optional[str] = None
    local_mode: Optional[LocalMode] = None  # overrides AddonConfig.local_mode


@dataclass
class AddonConfig:
    runtime: list[Addon] = field(default_factory=list)
    editor: list[Addon] = field(default_factory=list)
    local_namespace: Optional[str] = None
    local_mode: LocalMode = "copy"


def load_config(path: Path = CONFIG_FILE) -> AddonConfig:
    data = yaml.safe_load(path.read_text())

    def parse_addons(items: list | None) -> list[Addon]:
        if not items:
            return []
        result = []
        for item in items:
            addon = Addon(
                repo=item["repo"],
                ref=str(item["ref"]),
                source=item.get("source"),
                target=item.get("target"),
                local_mode=item.get("local_mode"),
            )
            if addon.source and not addon.target:
                raise ValueError(
                    f"Addon {addon.repo!r}: 'target' is required when 'source' is specified"
                )
            result.append(addon)
        return result

    return AddonConfig(
        runtime=parse_addons(data.get("runtime")),
        editor=parse_addons(data.get("editor")),
        local_namespace=data.get("local_namespace"),
        local_mode=data.get("local_mode", "copy"),
    )


def load_lock(path: Path = LOCKFILE) -> dict[str, dict]:
    if not path.exists():
        return {}
    raw = json.loads(path.read_text())
    # Migrate legacy flat-string entries to dict format
    result = {}
    for key, value in raw.items():
        if isinstance(value, str):
            if value.startswith("local:"):
                result[key] = {"local": value[len("local:"):], "mode": "copy"}
            else:
                result[key] = {}  # unknown legacy format; treat as stale
        else:
            result[key] = value
    return result


def save_lock(lock: dict[str, dict], path: Path = LOCKFILE) -> None:
    path.write_text(json.dumps(lock, indent=2) + "\n")


def get_local_namespace(config_value: Optional[str]) -> str:
    return config_value or f"{Path.cwd().name}-addons"


def get_local_path(namespace: str, addon: Addon) -> Optional[Path]:
    if not addon.source or not addon.target:
        return None
    candidate = Path("..") / namespace / addon.target / addon.source
    return candidate if candidate.exists() else None


def create_symlink(src: Path, dst: Path) -> None:
    resolved = src.resolve()
    if sys.platform == "win32":
        try:
            os.symlink(resolved, dst, target_is_directory=True)
        except OSError:
            subprocess.run(
                ["cmd", "/c", "mklink", "/J", str(dst), str(resolved)],
                check=True,
                capture_output=True,
            )
    else:
        os.symlink(resolved, dst)


def _remove_dest(dest: Path) -> None:
    if dest.is_symlink():
        dest.unlink()
    elif dest.is_junction():  # Windows junction; Path.is_junction() requires Python 3.12
        os.rmdir(dest)
    elif dest.exists():
        shutil.rmtree(dest)


def github_owner_repo(repo: str) -> str:
    repo = repo.rstrip("/")
    if repo.endswith(".git"):
        repo = repo[:-4]
    parts = repo.split("/")
    return f"{parts[-2]}/{parts[-1]}"


def resolve_commit_sha(repo: str, ref: str) -> str:
    url = f"https://api.github.com/repos/{github_owner_repo(repo)}/commits/{ref}"
    response = requests.get(
        url,
        headers={"Accept": "application/vnd.github.sha"},
        timeout=10,
    )
    response.raise_for_status()
    return response.text.strip()


def github_archive_url(repo: str, ref: str) -> str:
    repo = repo.rstrip("/")
    if repo.endswith(".git"):
        repo = repo[:-4]
    return f"{repo}/archive/{ref}.zip"


def download_and_extract(repo: str, ref: str, tmp_dir: Path) -> Path:
    url = github_archive_url(repo, ref)
    response = requests.get(url, timeout=30, stream=True)
    response.raise_for_status()

    zip_path = tmp_dir / "archive.zip"
    with open(zip_path, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)

    extract_dir = tmp_dir / "extracted"
    extract_dir.mkdir()
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_dir)

    children = [p for p in extract_dir.iterdir() if p.is_dir()]
    if len(children) == 1:
        return children[0]
    return extract_dir


def find_addon_dirs(archive_root: Path) -> list[Path]:
    addons_path = archive_root / "addons"
    if not addons_path.is_dir():
        return []
    return sorted(p for p in addons_path.iterdir() if p.is_dir())


def install_addon_local_copy(addon: Addon, local_path: Path, lock: dict[str, dict], force: bool = False) -> bool:
    target_name = addon.target
    dest = ADDONS_DIR / target_name
    local_str = str(local_path.resolve())

    entry = lock.get(target_name, {})
    if not force and dest.exists() and not dest.is_symlink() and not dest.is_junction():
        if entry.get("local") == local_str:
            print(f"  {target_name}: up to date (local copy)")
            return True

    _remove_dest(dest)
    try:
        shutil.copytree(local_path, dest)
        lock[target_name] = {"local": local_str, "mode": "copy"}
        print(f"  {target_name}: copied from {local_path}")
        return True
    except Exception as e:
        print(f"  ERROR copying {target_name}: {e}")
        return False


def install_addon_local_symlink(addon: Addon, local_path: Path, lock: dict[str, dict], force: bool = False) -> bool:
    target_name = addon.target
    dest = ADDONS_DIR / target_name
    local_str = str(local_path.resolve())

    entry = lock.get(target_name, {})
    if not force and (dest.is_symlink() or dest.is_junction()):
        if entry.get("local") == local_str:
            print(f"  {target_name}: up to date (symlink)")
            return True

    _remove_dest(dest)
    try:
        create_symlink(local_path, dest)
        lock[target_name] = {"local": local_str, "mode": "symlink"}
        print(f"  {target_name}: linked -> {local_path}")
        return True
    except Exception as e:
        print(f"  ERROR creating symlink for {target_name}: {e}")
        return False


def install_addon_prod(
    addon: Addon,
    lock: dict[str, dict],
    force: bool = False,
    resolved_sha: Optional[str] = None,
) -> bool:
    with tempfile.TemporaryDirectory() as tmp:
        tmp_dir = Path(tmp)
        try:
            if addon.source:
                target_name = addon.target
                entry = lock.get(target_name, {})
                dest = ADDONS_DIR / target_name

                if not force and dest.exists() and not dest.is_symlink() and not dest.is_junction():
                    if entry.get("ref") == addon.ref and entry.get("sha"):
                        sha = entry["sha"]
                        print(f"  {target_name}: up to date ({addon.ref} @ {sha[:7]})")
                        return True

                if resolved_sha is None:
                    print(f"  Resolving {addon.repo} @ {addon.ref}...")
                    resolved_sha = resolve_commit_sha(addon.repo, addon.ref)

                print(f"  Downloading {addon.repo} @ {resolved_sha[:7]}...")
                archive_root = download_and_extract(addon.repo, resolved_sha, tmp_dir)
                source_path = archive_root / addon.source

                if not source_path.exists():
                    print(f"  ERROR: source '{addon.source}' not found in archive for {addon.repo}")
                    return False

                _remove_dest(dest)
                shutil.copytree(source_path, dest)
                lock[target_name] = {"ref": addon.ref, "sha": resolved_sha}
                print(f"  Installed: {target_name} ({addon.ref} @ {resolved_sha[:7]})")

            else:
                # Auto-detect: no SHA pinning; download at the ref string directly
                print(f"  Downloading {addon.repo} @ {addon.ref}...")
                archive_root = download_and_extract(addon.repo, addon.ref, tmp_dir)
                addon_dirs = find_addon_dirs(archive_root)

                if not addon_dirs:
                    print(f"  ERROR: no addons/ directory found in {addon.repo}")
                    return False

                for addon_dir in addon_dirs:
                    name = addon_dir.name
                    entry = lock.get(name, {})
                    dest = ADDONS_DIR / name
                    if not force and dest.exists() and not dest.is_symlink() and not dest.is_junction():
                        if entry.get("ref") == addon.ref:
                            print(f"  {name}: up to date ({addon.ref})")
                            continue
                    _remove_dest(dest)
                    shutil.copytree(addon_dir, dest)
                    lock[name] = {"ref": addon.ref}
                    print(f"  Installed: {name} ({addon.ref})")

        except requests.HTTPError as e:
            print(f"  ERROR: HTTP {e.response.status_code} for {addon.repo} @ {addon.ref}")
            return False
        except Exception as e:
            print(f"  ERROR installing {addon.repo}: {e}")
            return False

    return True


def ensure_gitignore(patterns: list[str]) -> None:
    existing = GITIGNORE.read_text().splitlines() if GITIGNORE.exists() else []
    new_lines = [p for p in patterns if p not in existing]
    if new_lines:
        with open(GITIGNORE, "a") as f:
            for line in new_lines:
                f.write(line + "\n")


def _print_addon_status(addons: list[Addon], lock: dict[str, dict]) -> None:
    for addon in addons:
        if addon.target:
            name = addon.target
            entry = lock.get(name, {})
            dest = ADDONS_DIR / name
            if not dest.exists():
                print(f"  {name}: NOT INSTALLED (config: {addon.ref})")
            elif "local" in entry:
                mode = entry.get("mode", "copy")
                print(f"  {name}: local {mode} -> {entry['local']}")
            elif entry.get("ref") == addon.ref and entry.get("sha"):
                sha = entry["sha"]
                print(f"  {name}: ok ({addon.ref} @ {sha[:7]})")
            elif entry.get("sha"):
                sha = entry["sha"]
                print(f"  {name}: STALE (installed: {entry.get('ref')} @ {sha[:7]}, config: {addon.ref})")
            else:
                print(f"  {name}: STALE (no sha in lock, config: {addon.ref})")
        else:
            print(f"  {addon.repo} @ {addon.ref}: auto-detect (run sync to inspect)")


def cmd_sync_dev(config: AddonConfig, force: bool) -> None:
    cmd_clone_local(config)
    ADDONS_DIR.mkdir(exist_ok=True)
    lock = load_lock()
    namespace = get_local_namespace(config.local_namespace)
    for addon in config.runtime + config.editor:
        local_path = get_local_path(namespace, addon)
        if local_path is not None:
            mode = addon.local_mode or config.local_mode
            if mode == "symlink":
                install_addon_local_symlink(addon, local_path, lock, force=force)
            else:
                install_addon_local_copy(addon, local_path, lock, force=force)
        else:
            install_addon_prod(addon, lock, force=force)
    save_lock(lock)
    ensure_gitignore(["addons/", "addons.lock.json"])


def cmd_sync_prod(config: AddonConfig, force: bool) -> None:
    ADDONS_DIR.mkdir(exist_ok=True)
    lock = load_lock()
    for addon in config.runtime:
        install_addon_prod(addon, lock, force=force)
    save_lock(lock)
    ensure_gitignore(["addons/", "addons.lock.json"])


def cmd_update(config: AddonConfig, dev: bool) -> None:
    ADDONS_DIR.mkdir(exist_ok=True)
    lock = load_lock()
    addons = config.runtime + config.editor if dev else config.runtime
    for addon in addons:
        if not addon.target:
            print(f"  {addon.repo}: auto-detect, skipping")
            continue
        entry = lock.get(addon.target, {})
        if "local" in entry:
            print(f"  {addon.target}: local install, skipping")
            continue
        print(f"  Resolving {addon.repo} @ {addon.ref}...")
        try:
            sha = resolve_commit_sha(addon.repo, addon.ref)
        except Exception as e:
            print(f"  ERROR resolving {addon.repo}: {e}")
            continue
        old_sha = entry.get("sha", "")
        if entry.get("ref") == addon.ref and old_sha == sha:
            print(f"  {addon.target}: already at latest ({addon.ref} @ {sha[:7]})")
            continue
        arrow = f"{old_sha[:7]} -> {sha[:7]}" if old_sha else sha[:7]
        print(f"  {addon.target}: {arrow}")
        install_addon_prod(addon, lock, force=True, resolved_sha=sha)
    save_lock(lock)
    ensure_gitignore(["addons/", "addons.lock.json"])


def _git(args: list[str], cwd: Path, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(["git", "-C", str(cwd)] + args, **kwargs)


def _current_ref(repo_dir: Path) -> str:
    result = _git(["rev-parse", "--abbrev-ref", "HEAD"], repo_dir, capture_output=True, text=True)
    if result.returncode != 0:
        return "unknown"
    current = result.stdout.strip()
    if current == "HEAD":
        result = _git(["describe", "--tags", "--exact-match"], repo_dir, capture_output=True, text=True)
        return result.stdout.strip() if result.returncode == 0 else "HEAD (detached)"
    return current


def cmd_clone_local(config: AddonConfig) -> None:
    namespace = get_local_namespace(config.local_namespace)
    for addon in config.runtime + config.editor:
        if not addon.local_mode or not addon.target:
            continue
        repo_dir = Path("..") / namespace / addon.target
        if not repo_dir.exists():
            repo_dir.parent.mkdir(parents=True, exist_ok=True)
            print(f"  Cloning {addon.repo} @ {addon.ref}...")
            try:
                subprocess.run(
                    ["git", "clone", "--branch", addon.ref, addon.repo, str(repo_dir)],
                    check=True,
                )
                print(f"  {addon.target}: cloned ({addon.ref})")
            except subprocess.CalledProcessError as e:
                print(f"  ERROR cloning {addon.repo}: {e}")
            continue

        try:
            _git(["fetch", "--quiet"], repo_dir, check=True, capture_output=True)
        except subprocess.CalledProcessError:
            print(f"  {addon.target}: fetch failed, skipping ref check")
            continue

        current = _current_ref(repo_dir)
        if current == addon.ref:
            print(f"  {addon.target}: ok ({addon.ref})")
            continue

        status = _git(["status", "--porcelain"], repo_dir, capture_output=True, text=True, check=True)
        if status.stdout.strip():
            print(f"  {addon.target}: WARNING on '{current}', expected '{addon.ref}' (uncommitted changes, skipping checkout)")
        else:
            try:
                _git(["checkout", addon.ref], repo_dir, check=True, capture_output=True)
                print(f"  {addon.target}: switched {current} -> {addon.ref}")
            except subprocess.CalledProcessError:
                print(f"  {addon.target}: WARNING on '{current}', expected '{addon.ref}' (checkout failed)")


def cmd_status(config: AddonConfig) -> None:
    lock = load_lock()
    print("Runtime addons:")
    _print_addon_status(config.runtime, lock)
    print("Editor addons:")
    _print_addon_status(config.editor, lock)


def main() -> None:
    if not Path("project.godot").exists():
        print("Error: must be run from project root (no project.godot found)", file=sys.stderr)
        sys.exit(1)

    parser = argparse.ArgumentParser(
        description="Sync Godot addons from GitHub",
        prog="sync_addons",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    for name in ("sync-dev", "sync-prod"):
        p = sub.add_parser(name)
        p.add_argument("--force", action="store_true", help="Re-download/re-copy/re-link ignoring lock")

    p = sub.add_parser("update", help="Re-resolve refs to latest SHAs, re-download what changed")
    p.add_argument("--dev", action="store_true", help="Include editor addons")

    sub.add_parser("clone-local", help="Clone repos with local_mode set into the local namespace")
    sub.add_parser("status", help="Show installed vs config refs")

    args = parser.parse_args()
    config = load_config()

    if args.command == "sync-dev":
        cmd_sync_dev(config, args.force)
    elif args.command == "sync-prod":
        cmd_sync_prod(config, args.force)
    elif args.command == "update":
        cmd_update(config, args.dev)
    elif args.command == "clone-local":
        cmd_clone_local(config)
    elif args.command == "status":
        cmd_status(config)


if __name__ == "__main__":
    main()
