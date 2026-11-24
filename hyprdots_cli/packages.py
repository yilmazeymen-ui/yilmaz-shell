"""System package detection and interactive installation (Arch/CachyOS)."""

from __future__ import annotations

import shutil
import subprocess
import sys


def get_installed_packages() -> set[str] | None:
    """Return installed pacman/AUR package names, or None if pacman is unavailable."""
    if not shutil.which("pacman"):
        return None
    res = subprocess.run(
        ["pacman", "-Qq"],
        capture_output=True,
        text=True,
        check=False,
    )
    if res.returncode != 0:
        return None
    return {line.strip() for line in res.stdout.splitlines() if line.strip()}


def detect_aur_helper() -> str | None:
    """Return the first available AUR helper ('yay' or 'paru')."""
    for helper in ("yay", "paru"):
        if shutil.which(helper):
            return helper
    return None


def find_missing_packages(
    pacman_pkgs: list[str],
    aur_pkgs: list[str],
) -> tuple[list[str], list[str]]:
    """Return (missing_pacman, missing_aur) package lists."""
    installed = get_installed_packages()
    if installed is None:
        return [], []
    missing_pac = [p for p in pacman_pkgs if p not in installed]
    missing_aur = [p for p in aur_pkgs if p not in installed]
    return missing_pac, missing_aur


def prompt_and_install_packages(
    pacman_pkgs: list[str],
    aur_pkgs: list[str],
    dry_run: bool = False,
    assume_yes: bool = False,
) -> bool:
    """Check missing desktop packages, prompt user, and install if approved.

    Returns True if everything succeeded or nothing needed installing.
    """
    missing_pac, missing_aur = find_missing_packages(pacman_pkgs, aur_pkgs)
    if not missing_pac and not missing_aur:
        return True

    all_missing = missing_pac + missing_aur
    print(f"Eksik masaüstü paketleri ({len(all_missing)} adet):")
    if missing_pac:
        print("  [pacman] " + ", ".join(missing_pac))
    if missing_aur:
        print("  [AUR]    " + ", ".join(missing_aur))

    if dry_run:
        print("[DRY-RUN] Paket kurulumu atlandı.")
        return True

    if not assume_yes:
        if not sys.stdin.isatty():
            print("Etkileşimli terminal yok; paket kurulumu atlandı (otomatik onay için --yes kullanın).")
            return True
        ans = input("Eksik paketler otomatik olarak yüklensin mi? [e/H]: ").strip().lower()
        if ans not in {"e", "evet", "y", "yes"}:
            print("Paket kurulumu kullanıcı tarafından atlandı.")
            return True

    ok = True
    if missing_pac:
        res = subprocess.run(["sudo", "pacman", "-S", "--needed", *missing_pac], check=False)
        if res.returncode != 0:
            ok = False

    if missing_aur:
        helper = detect_aur_helper()
        if helper:
            res = subprocess.run([helper, "-S", "--needed", *missing_aur], check=False)
            if res.returncode != 0:
                ok = False
        else:
            print(
                "Uyarı: AUR yardımcısı (yay/paru) bulunamadı; şu paketler elle kurulmalı: "
                + ", ".join(missing_aur),
                file=sys.stderr,
            )

    return ok
