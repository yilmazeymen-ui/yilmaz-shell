"""Hyprland plugin installation and build helpers."""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

from .config import PluginSpec


def ensure_plugin(
    plugin: PluginSpec,
    target_home: Path,
    dry_run: bool = False,
    force_rebuild: bool = False,
) -> tuple[bool, str]:
    """Clone and build a Hyprland plugin if its artifact is missing.

    Returns (ok, status_message).
    """
    dest_dir = target_home / plugin.dest
    artifact_path = dest_dir / plugin.artifact

    if artifact_path.exists() and not force_rebuild:
        return True, f"{plugin.name}: zaten kurulu ({artifact_path})"

    if dry_run:
        return True, f"[DRY-RUN] {plugin.name}: {plugin.repo} -> {dest_dir} kurulacak"

    if not shutil.which("git") or not shutil.which("make"):
        return False, f"{plugin.name}: kurulum için 'git' ve 'make' gerekli."

    dest_dir.parent.mkdir(parents=True, exist_ok=True)
    if not (dest_dir / ".git").exists():
        res = subprocess.run(
            ["git", "clone", "--depth", "1", plugin.repo, str(dest_dir)],
            capture_output=True,
            text=True,
            check=False,
        )
        if res.returncode != 0:
            err = res.stderr.strip() or res.stdout.strip()
            return False, f"{plugin.name}: git clone başarısız: {err}"
    else:
        subprocess.run(
            ["git", "-C", str(dest_dir), "pull", "--ff-only"],
            capture_output=True,
            text=True,
            check=False,
        )

    jobs = str(os.cpu_count() or 4)
    build_res = subprocess.run(
        ["make", f"-j{jobs}"],
        cwd=str(dest_dir),
        capture_output=True,
        text=True,
        check=False,
    )
    if build_res.returncode != 0 or not artifact_path.exists():
        err = build_res.stderr.strip() or build_res.stdout.strip()
        tail = "\n".join(err.splitlines()[-10:])
        return False, f"{plugin.name}: derleme başarısız:\n{tail}"

    return True, f"{plugin.name}: derlendi ve kuruldu ({artifact_path})"
