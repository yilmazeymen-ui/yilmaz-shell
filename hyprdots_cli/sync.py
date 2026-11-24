"""Core export, install, and status synchronization logic."""

from __future__ import annotations

import shutil
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from .config import Manifest, is_excluded
from .sanitizer import render_text, sanitize_text


@dataclass
class SyncReport:
    """Summary of files processed during export or install."""

    copied: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    backed_up: list[str] = field(default_factory=list)
    backup_dir: Path | None = None


def _is_text_file(data: bytes) -> bool:
    if b"\x00" in data:
        return False
    try:
        data.decode("utf-8")
        return True
    except UnicodeDecodeError:
        return False


def _iter_target_files(base_dir: Path, target: str, manifest: Manifest) -> list[tuple[Path, str]]:
    """Return (full_path, rel_posix_path) for all non-excluded files under base_dir/target."""
    target_dir = base_dir / target
    if not target_dir.exists():
        return []

    results: list[tuple[Path, str]] = []
    for path in sorted(target_dir.rglob("*")):
        if not path.is_file() or path.is_symlink():
            continue
        rel = path.relative_to(base_dir).as_posix()
        if is_excluded(rel, manifest):
            continue
        results.append((path, rel))
    return results


def export_configs(
    repo_root: Path,
    manifest: Manifest,
    source_config_dir: Path | None = None,
    source_home: Path | None = None,
    dry_run: bool = False,
) -> SyncReport:
    """Export and sanitize configs from ~/.config into repo_root/configs."""
    home = source_home or Path.home()
    src_cfg = source_config_dir or (home / ".config")
    dest_cfg = repo_root / "configs"
    report = SyncReport()

    if not dry_run:
        for target in manifest.targets:
            target_dest = dest_cfg / target
            if target_dest.exists():
                shutil.rmtree(target_dest)

    for target in manifest.targets:
        target_root = src_cfg / target
        if not target_root.exists():
            report.skipped.append(f"{target} (kaynak bulunamadı)")
            continue

        for src_file, rel in _iter_target_files(src_cfg, target, manifest):
            raw = src_file.read_bytes()
            out_file = dest_cfg / rel
            report.copied.append(rel)

            if dry_run:
                continue

            out_file.parent.mkdir(parents=True, exist_ok=True)
            if _is_text_file(raw):
                sanitized = sanitize_text(rel, raw.decode("utf-8"), home)
                out_file.write_text(sanitized, encoding="utf-8")
            else:
                out_file.write_bytes(raw)
            shutil.copymode(src_file, out_file)

    return report


def install_configs(
    repo_root: Path,
    manifest: Manifest,
    target_home: Path | None = None,
    has_nvidia: bool = False,
    dry_run: bool = False,
    skip_backup: bool = False,
) -> SyncReport:
    """Render and install configs from repo_root/configs into target_home/.config."""
    home = target_home or Path.home()
    src_cfg = repo_root / "configs"
    dest_cfg = home / ".config"
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_root = dest_cfg / ".hyprdots-backup" / timestamp
    report = SyncReport()

    for target in manifest.targets:
        if not (src_cfg / target).exists():
            report.skipped.append(f"{target} (repoda yok)")
            continue

        for src_file, rel in _iter_target_files(src_cfg, target, manifest):
            raw = src_file.read_bytes()
            dest_file = dest_cfg / rel
            report.copied.append(rel)

            if dry_run:
                if dest_file.exists() and not skip_backup:
                    report.backed_up.append(rel)
                continue

            if dest_file.exists() and not skip_backup:
                backup_file = backup_root / rel
                backup_file.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(dest_file, backup_file)
                report.backed_up.append(rel)
                report.backup_dir = backup_root

            dest_file.parent.mkdir(parents=True, exist_ok=True)
            if _is_text_file(raw):
                rendered = render_text(rel, raw.decode("utf-8"), home, has_nvidia=has_nvidia)
                dest_file.write_text(rendered, encoding="utf-8")
            else:
                dest_file.write_bytes(raw)
            shutil.copymode(src_file, dest_file)

    return report


def diff_summary(
    repo_root: Path,
    manifest: Manifest,
    target_home: Path | None = None,
    has_nvidia: bool = False,
) -> dict[str, list[str]]:
    """Compare rendered repo configs against installed ~/.config files."""
    home = target_home or Path.home()
    src_cfg = repo_root / "configs"
    dest_cfg = home / ".config"

    same: list[str] = []
    modified: list[str] = []
    missing_local: list[str] = []

    for target in manifest.targets:
        for src_file, rel in _iter_target_files(src_cfg, target, manifest):
            dest_file = dest_cfg / rel
            if not dest_file.exists():
                missing_local.append(rel)
                continue

            raw = src_file.read_bytes()
            if _is_text_file(raw):
                expected = render_text(rel, raw.decode("utf-8"), home, has_nvidia=has_nvidia).encode(
                    "utf-8"
                )
            else:
                expected = raw

            if dest_file.read_bytes() == expected:
                same.append(rel)
            else:
                modified.append(rel)

    return {"same": same, "modified": modified, "missing_local": missing_local}
