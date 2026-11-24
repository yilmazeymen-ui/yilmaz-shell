import stat
import tempfile
import unittest
from pathlib import Path

from hyprdots_cli.config import Manifest, load_manifest
from hyprdots_cli.sync import diff_summary, export_configs, install_configs


class SyncTests(unittest.TestCase):
    def _make_manifest(self) -> Manifest:
        return Manifest(
            name="hyprdots",
            description="test",
            targets=["hypr", "kitty", "fish"],
            exclude_globs=["*.bak", "*.save", ".git", ".git/**"],
            exclude_paths={"hypr/scripts/audio-restore.sh", "fish/fish_variables"},
            dependencies=[],
            wallpapers_source="Resimler/Arkaplan",
            wallpapers_target_subdir="Wallpapers",
        )

    def test_export_and_install_roundtrip_with_backup(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            src_home = tmp_path / "src_home"
            src_cfg = src_home / ".config"
            repo_root = tmp_path / "repo"
            dst_home = tmp_path / "dst_home"
            dst_cfg = dst_home / ".config"

            # Populate source configs
            (src_cfg / "hypr/confs").mkdir(parents=True)
            (src_cfg / "hypr/scripts").mkdir(parents=True)
            (src_cfg / "kitty").mkdir(parents=True)
            (src_cfg / "fish").mkdir(parents=True)
            (src_cfg / "quickshell/liquid-glass/.git").mkdir(parents=True)

            (src_cfg / "hypr/confs/env.lua").write_text(
                '-- Nvidia\nhl.env("GBM_BACKEND", "nvidia-drm")\n',
                encoding="utf-8",
            )
            script = src_cfg / "hypr/scripts/hello.sh"
            script.write_text(f"#!/bin/bash\necho {src_home}\n", encoding="utf-8")
            script.chmod(script.stat().st_mode | stat.S_IXUSR)

            # Excluded files
            (src_cfg / "hypr/confs/env.lua.bak").write_text("backup", encoding="utf-8")
            (src_cfg / "hypr/scripts/audio-restore.sh").write_text("hdmi", encoding="utf-8")
            (src_cfg / "fish/fish_variables").write_text("vars", encoding="utf-8")
            (src_cfg / "fish/config.fish.save").write_text("save", encoding="utf-8")

            # Binary file
            (src_cfg / "kitty/icon.bin").write_bytes(b"\x00\x01\x02\xff")

            # Wallpaper file
            (src_home / "Resimler/Arkaplan/yeni").mkdir(parents=True)
            (src_home / "Resimler/Arkaplan/yeni/Desen.png").write_bytes(b"PNGDATA")
            (src_cfg / "hypr/vars").mkdir(parents=True)
            (src_cfg / "hypr/vars/bg").write_text(
                f"{src_home}/Resimler/Arkaplan/yeni/Desen.png\n",
                encoding="utf-8",
            )

            # Existing file on destination to verify backup
            (dst_cfg / "kitty").mkdir(parents=True)
            (dst_cfg / "kitty/icon.bin").write_bytes(b"old-bytes")

            manifest = self._make_manifest()
            exp = export_configs(
                repo_root=repo_root,
                manifest=manifest,
                source_config_dir=src_cfg,
                source_home=src_home,
            )
            self.assertIn("hypr/confs/env.lua", exp.copied)
            self.assertIn("hypr/scripts/hello.sh", exp.copied)
            self.assertIn("kitty/icon.bin", exp.copied)
            self.assertNotIn("hypr/confs/env.lua.bak", exp.copied)
            self.assertNotIn("hypr/scripts/audio-restore.sh", exp.copied)
            self.assertNotIn("fish/fish_variables", exp.copied)
            self.assertNotIn("fish/config.fish.save", exp.copied)

            inst = install_configs(
                repo_root=repo_root,
                manifest=manifest,
                target_home=dst_home,
                has_nvidia=False,
            )
            self.assertIsNotNone(inst.backup_dir)
            self.assertIn("kitty/icon.bin", inst.backed_up)
            self.assertEqual((inst.backup_dir / "kitty/icon.bin").read_bytes(), b"old-bytes")
            self.assertEqual((dst_cfg / "kitty/icon.bin").read_bytes(), b"\x00\x01\x02\xff")

            installed_script = dst_cfg / "hypr/scripts/hello.sh"
            self.assertTrue(bool(installed_script.stat().st_mode & stat.S_IXUSR))
            self.assertIn(str(dst_home), installed_script.read_text(encoding="utf-8"))
            self.assertNotIn("nvidia-drm", (dst_cfg / "hypr/confs/env.lua").read_text(encoding="utf-8"))

            summary = diff_summary(repo_root, manifest, target_home=dst_home, has_nvidia=False)
            self.assertEqual(len(summary["modified"]), 0)
            self.assertEqual(len(summary["missing_local"]), 0)
            self.assertEqual(len(summary["same"]), 4)
            self.assertEqual(inst.wallpapers_copied, 1)
            self.assertTrue((dst_home / "Pictures/Wallpapers/yeni/Desen.png").exists())
            self.assertEqual(
                (dst_cfg / "hypr/vars/bg").read_text(encoding="utf-8").strip(),
                f"{dst_home}/Pictures/Wallpapers/yeni/Desen.png",
            )

    def test_repo_manifest_loads_targets(self) -> None:
        manifest = load_manifest()
        self.assertIn("hypr", manifest.targets)
        self.assertIn("quickshell/liquid-glass", manifest.targets)
        self.assertIn("kitty", manifest.targets)
        self.assertIn("hypr/scripts/audio-restore.sh", manifest.exclude_paths)
        self.assertTrue(any(p.name == "hyprglass" for p in manifest.plugins))
        self.assertIn("kitty/kitty.conf", manifest.preserve_if_exists)
        self.assertIn("hypr/confs/keybindings.lua", manifest.preserve_if_exists)

    def test_preserve_if_exists_skips_custom_files_unless_forced(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            repo_root = tmp_path / "repo"
            dst_home = tmp_path / "home"
            (repo_root / "configs/kitty").mkdir(parents=True)
            (repo_root / "configs/quickshell/liquid-glass").mkdir(parents=True)
            (repo_root / "configs/kitty/kitty.conf").write_text("background_opacity 0.2\n", encoding="utf-8")
            (repo_root / "configs/quickshell/liquid-glass/Theme.qml").write_text("v2\n", encoding="utf-8")

            manifest = Manifest(
                name="hyprdots",
                description="test",
                targets=["kitty", "quickshell/liquid-glass"],
                exclude_globs=[],
                exclude_paths=set(),
                dependencies=[],
                preserve_if_exists={"kitty/kitty.conf"},
            )

            # First install: installs both
            first = install_configs(repo_root, manifest, target_home=dst_home, skip_wallpapers=True)
            self.assertIn("kitty/kitty.conf", first.copied)
            self.assertEqual(first.preserved, [])

            # User customizes kitty.conf
            kitty_dst = dst_home / ".config/kitty/kitty.conf"
            kitty_dst.write_text("background_opacity 0.9\n", encoding="utf-8")

            # Update/reinstall without force: preserves kitty.conf, updates Theme.qml
            second = install_configs(repo_root, manifest, target_home=dst_home, skip_wallpapers=True)
            self.assertIn("kitty/kitty.conf", second.preserved)
            self.assertIn("quickshell/liquid-glass/Theme.qml", second.copied)
            self.assertEqual(kitty_dst.read_text(encoding="utf-8"), "background_opacity 0.9\n")

            # Install with force=True: overwrites kitty.conf
            third = install_configs(
                repo_root, manifest, target_home=dst_home, skip_wallpapers=True, force=True
            )
            self.assertIn("kitty/kitty.conf", third.copied)
            self.assertEqual(kitty_dst.read_text(encoding="utf-8"), "background_opacity 0.2\n")


if __name__ == "__main__":
    unittest.main()
