"""Configuration and manifest loading for hyprdots."""

from __future__ import annotations

import fnmatch
import tomllib
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class PluginSpec:
    """Represents a buildable Hyprland plugin entry."""

    name: str
    repo: str
    dest: str
    artifact: str


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
    plugins: list[PluginSpec] = ()  # type: ignore[assignment]
    pacman_packages: list[str] = ()  # type: ignore[assignment]
    aur_packages: list[str] = ()  # type: ignore[assignment]
    preserve_if_exists: set[str] = frozenset()  # type: ignore[assignment]


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
    raw_plugins = data.get("plugins", {})
    packages = data.get("packages", {})
    plugins = [
        PluginSpec(
            name=name,
            repo=spec["repo"],
            dest=spec["dest"],
            artifact=spec["artifact"],
        )
        for name, spec in raw_plugins.items()
    ]
    return Manifest(
        name=meta.get("name", "hyprdots"),
        description=meta.get("description", ""),
        targets=list(data.get("targets", [])),
        exclude_globs=list(data.get("exclude_globs", [])),
        exclude_paths=set(data.get("exclude_paths", [])),
        dependencies=list(data.get("dependencies", [])),
        wallpapers_source=wallpapers.get("source", ""),
        wallpapers_target_subdir=wallpapers.get("target_subdir", "Wallpapers"),
        plugins=plugins,
        pacman_packages=list(packages.get("pacman", [])),
        aur_packages=list(packages.get("aur", [])),
        preserve_if_exists=set(data.get("preserve_if_exists", [])),
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
