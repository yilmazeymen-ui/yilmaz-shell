"""Configuration and manifest loading for hyprdots."""

from __future__ import annotations

import fnmatch
import tomllib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Manifest:
    """Represents the parsed manifest.toml configuration."""

    name: str
    description: str
    targets: list[str]
    exclude_globs: list[str]
    exclude_paths: set[str]
    dependencies: list[str]
    wallpapers_source: str = ""
    wallpapers_target_subdir: str = "Wallpapers"


def get_repo_root() -> Path:
    """Return the root directory of the hyprdots repository."""
    return Path(__file__).resolve().parent.parent


def load_manifest(repo_root: Path | None = None) -> Manifest:
    """Load and parse manifest.toml from the repository root."""
    root = repo_root or get_repo_root()
    manifest_path = root / "manifest.toml"
    with manifest_path.open("rb") as f:
        data = tomllib.load(f)

    meta = data.get("meta", {})
    wallpapers = data.get("wallpapers", {})
    return Manifest(
        name=meta.get("name", "hyprdots"),
        description=meta.get("description", ""),
        targets=list(data.get("targets", [])),
        exclude_globs=list(data.get("exclude_globs", [])),
        exclude_paths=set(data.get("exclude_paths", [])),
        dependencies=list(data.get("dependencies", [])),
        wallpapers_source=wallpapers.get("source", ""),
        wallpapers_target_subdir=wallpapers.get("target_subdir", "Wallpapers"),
    )


def is_excluded(rel_path: str, manifest: Manifest) -> bool:
    """Check whether a config-relative POSIX path should be excluded."""
    if rel_path in manifest.exclude_paths:
        return True

    parts = rel_path.split("/")
    for glob in manifest.exclude_globs:
        if fnmatch.fnmatch(rel_path, glob):
            return True
        if any(fnmatch.fnmatch(part, glob) for part in parts):
            return True
    return False
