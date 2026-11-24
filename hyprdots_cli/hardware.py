"""Hardware and dependency detection helpers."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


def detect_nvidia() -> bool:
    """Return True if an Nvidia GPU/driver is detected on the current machine."""
    if Path("/proc/driver/nvidia/version").exists():
        return True

    if shutil.which("nvidia-smi"):
        try:
            res = subprocess.run(
                ["nvidia-smi", "-L"],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
            if res.returncode == 0 and "GPU" in res.stdout:
                return True
        except (OSError, subprocess.SubprocessError):
            pass

    if shutil.which("lspci"):
        try:
            res = subprocess.run(
                ["lspci"],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
            if res.returncode == 0:
                for line in res.stdout.splitlines():
                    upper = line.upper()
                    if ("VGA" in upper or "3D" in upper) and "NVIDIA" in upper:
                        return True
        except (OSError, subprocess.SubprocessError):
            pass

    return False


def check_dependencies(commands: list[str]) -> tuple[list[str], list[str]]:
    """Return (installed, missing) command lists."""
    installed: list[str] = []
    missing: list[str] = []
    for cmd in commands:
        if shutil.which(cmd):
            installed.append(cmd)
        else:
            missing.append(cmd)
    return installed, missing


def resolve_pictures_dir(target_home: Path) -> Path:
    """Resolve XDG Pictures directory for target_home, falling back to ~/Pictures."""
    if target_home.resolve() == Path.home().resolve() and shutil.which("xdg-user-dir"):
        try:
            res = subprocess.run(
                ["xdg-user-dir", "PICTURES"],
                capture_output=True,
                text=True,
                timeout=3,
                check=False,
            )
            out = res.stdout.strip()
            if res.returncode == 0 and out:
                return Path(out)
        except (OSError, subprocess.SubprocessError):
            pass
    return target_home / "Pictures"
