"""Command-line interface for hyprdots."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .config import get_repo_root, load_manifest
from .git_ops import GitError, current_branch, is_git_repo, list_remote_branches, update_branch
from .hardware import check_dependencies, detect_nvidia
from .plugins import ensure_plugin
from .sync import diff_summary, export_configs, install_configs


def _resolve_nvidia(args: argparse.Namespace) -> bool:
    if getattr(args, "nvidia", False):
        return True
    if getattr(args, "no_nvidia", False):
        return False
    return detect_nvidia()


def _cmd_export(args: argparse.Namespace) -> int:
    repo_root = get_repo_root()
    manifest = load_manifest(repo_root)
    source_cfg = Path(args.source).expanduser() if args.source else None
    report = export_configs(
        repo_root=repo_root,
        manifest=manifest,
        source_config_dir=source_cfg,
        dry_run=args.dry_run,
    )
    prefix = "[DRY-RUN] " if args.dry_run else ""
    print(f"{prefix}Export tamamlandı: {len(report.copied)} dosya işlendi.")
    if report.wallpapers_copied:
        print(f"{prefix}Duvar kağıdı: {report.wallpapers_copied} dosya ({report.wallpapers_dir})")
    for item in report.skipped:
        print(f"  Atlandı: {item}")
    if args.dry_run:
        for rel in report.copied:
            print(f"  + {rel}")
    else:
        print(f"Hedef: {repo_root / 'configs'}")
    return 0


def _cmd_install(args: argparse.Namespace) -> int:
    repo_root = get_repo_root()
    manifest = load_manifest(repo_root)
    has_nvidia = _resolve_nvidia(args)
    target_home = Path(args.home).expanduser() if args.home else None

    report = install_configs(
        repo_root=repo_root,
        manifest=manifest,
        target_home=target_home,
        has_nvidia=has_nvidia,
        dry_run=args.dry_run,
        skip_backup=args.skip_backup,
        skip_wallpapers=args.skip_wallpapers,
    )
    prefix = "[DRY-RUN] " if args.dry_run else ""
    print(
        f"{prefix}Kurulum tamamlandı: {len(report.copied)} dosya "
        f"(Nvidia profili: {'açık' if has_nvidia else 'kapalı'})."
    )
    if report.wallpapers_copied:
        print(f"{prefix}Duvar kağıdı kuruldu: {report.wallpapers_copied} dosya -> {report.wallpapers_dir}")

    if not getattr(args, "skip_plugins", False):
        resolved_home = target_home or Path.home()
        for plugin in manifest.plugins:
            ok, msg = ensure_plugin(plugin, resolved_home, dry_run=args.dry_run)
            stream = sys.stdout if ok else sys.stderr
            print(msg, file=stream)
    if report.backup_dir:
        print(f"Yedek dizini: {report.backup_dir} ({len(report.backed_up)} dosya)")
    elif args.dry_run and report.backed_up:
        print(f"[DRY-RUN] Yedeklenecek dosya sayısı: {len(report.backed_up)}")

    _, missing = check_dependencies(manifest.dependencies)
    if missing:
        print("Eksik önerilen paket/komutlar:", ", ".join(missing))
    return 0


def _cmd_update(args: argparse.Namespace) -> int:
    repo_root = get_repo_root()
    if not is_git_repo(repo_root):
        print("Hata: Bu dizin bir git reposu değil.", file=sys.stderr)
        return 1

    branch = args.branch
    if args.interactive and not branch:
        branches = list_remote_branches(repo_root, remote=args.remote)
        if not branches:
            print("Uzak repoda dal bulunamadı.", file=sys.stderr)
            return 1
        print("Mevcut dallar:")
        for idx, name in enumerate(branches, 1):
            print(f"  {idx}) {name}")
        choice = input("Çekilecek dal numarası veya adı: ").strip()
        if choice.isdigit() and 1 <= int(choice) <= len(branches):
            branch = branches[int(choice) - 1]
        else:
            branch = choice

    try:
        active = update_branch(repo_root, branch=branch, remote=args.remote)
    except GitError as exc:
        print(f"Git hatası: {exc}", file=sys.stderr)
        return 1

    print(f"Dal güncellendi: {active}")
    if args.apply:
        return _cmd_install(args)
    return 0


def _cmd_branches(args: argparse.Namespace) -> int:
    repo_root = get_repo_root()
    if not is_git_repo(repo_root):
        print("Hata: Bu dizin bir git reposu değil.", file=sys.stderr)
        return 1
    try:
        branches = list_remote_branches(repo_root, remote=args.remote)
        active = current_branch(repo_root)
    except GitError as exc:
        print(f"Git hatası: {exc}", file=sys.stderr)
        return 1

    for name in branches:
        marker = "*" if name == active else " "
        print(f"{marker} {name}")
    return 0


def _cmd_status(args: argparse.Namespace) -> int:
    repo_root = get_repo_root()
    manifest = load_manifest(repo_root)
    if is_git_repo(repo_root):
        try:
            print(f"Aktif dal: {current_branch(repo_root)}")
        except GitError:
            pass

    has_nvidia = _resolve_nvidia(args)
    summary = diff_summary(repo_root, manifest, has_nvidia=has_nvidia)
    print(
        f"Durum -> Aynı: {len(summary['same'])}, "
        f"Farklı: {len(summary['modified'])}, "
        f"Sistemde yok: {len(summary['missing_local'])}"
    )
    for rel in summary["modified"]:
        print(f"  M {rel}")
    for rel in summary["missing_local"]:
        print(f"  ? {rel}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="hyprdots",
        description="Hyprland, Quickshell, Kitty ve ilgili config'leri paylaşma ve kurma aracı.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_exp = sub.add_parser("export", help="Sistemdeki ~/.config dosyalarını temizleyip repoya aktar.")
    p_exp.add_argument("--source", help="Kaynak config dizini (varsayılan: ~/.config)")
    p_exp.add_argument("--dry-run", action="store_true", help="Dosya yazmadan önizleme yap.")
    p_exp.set_defaults(func=_cmd_export)

    p_inst = sub.add_parser("install", help="Repodaki config'leri sisteme kur.")
    p_inst.add_argument("--home", help="Hedef HOME dizini (varsayılan: $HOME)")
    p_inst.add_argument("--dry-run", action="store_true", help="Değişiklik yapmadan önizleme yap.")
    p_inst.add_argument("--skip-backup", action="store_true", help="Mevcut dosyaları yedekleme.")
    p_inst.add_argument("--skip-wallpapers", action="store_true", help="Duvar kağıtlarını kurma.")
    p_inst.add_argument("--skip-plugins", action="store_true", help="Hyprland eklentilerini (hyprglass vb.) kurma.")
    nv_group = p_inst.add_mutually_exclusive_group()
    nv_group.add_argument("--nvidia", action="store_true", help="Nvidia ayarlarını zorla ekle.")
    nv_group.add_argument("--no-nvidia", action="store_true", help="Nvidia ayarlarını zorla kapat.")
    p_inst.set_defaults(func=_cmd_install)

    p_upd = sub.add_parser("update", help="GitHub'dan belirtilen dalı çek ve güncelle.")
    p_upd.add_argument("--branch", "-b", help="Çekilecek dal adı (varsayılan: aktif dal)")
    p_upd.add_argument("--remote", default="origin", help="Git remote adı (varsayılan: origin)")
    p_upd.add_argument("--interactive", "-i", action="store_true", help="Dalı listeden seç.")
    p_upd.add_argument("--apply", action="store_true", help="Güncelleme sonrası config'leri kur.")
    p_upd.add_argument("--home", help="Hedef HOME dizini (--apply ile)")
    p_upd.add_argument("--dry-run", action="store_true", help="--apply için önizleme.")
    p_upd.add_argument("--skip-backup", action="store_true", help="--apply için yedeklemeyi atla.")
    p_upd.add_argument("--skip-wallpapers", action="store_true", help="--apply için duvar kağıtlarını kurma.")
    p_upd.add_argument("--skip-plugins", action="store_true", help="--apply için Hyprland eklentilerini kurma.")
    nv_upd = p_upd.add_mutually_exclusive_group()
    nv_upd.add_argument("--nvidia", action="store_true", help="Nvidia ayarlarını zorla ekle.")
    nv_upd.add_argument("--no-nvidia", action="store_true", help="Nvidia ayarlarını zorla kapat.")
    p_upd.set_defaults(func=_cmd_update)

    p_br = sub.add_parser("branches", help="Uzak repodaki dalları listele.")
    p_br.add_argument("--remote", default="origin", help="Git remote adı")
    p_br.set_defaults(func=_cmd_branches)

    p_st = sub.add_parser("status", help="Repodaki ve sistemdeki config farklarını göster.")
    nv_st = p_st.add_mutually_exclusive_group()
    nv_st.add_argument("--nvidia", action="store_true", help="Nvidia profiliyle karşılaştır.")
    nv_st.add_argument("--no-nvidia", action="store_true", help="Nvidia profili olmadan karşılaştır.")
    p_st.set_defaults(func=_cmd_status)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return int(args.func(args))


if __name__ == "__main__":
    raise SystemExit(main())
