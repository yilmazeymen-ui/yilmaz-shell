import unittest
from pathlib import Path

from hyprdots_cli.sanitizer import (
    NVIDIA_ENV_MARKER,
    render_text,
    sanitize_text,
)


class SanitizerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.src_home = Path("/home/eymen")
        self.dst_home = Path("/home/alice")

    def test_monitor_lua_removes_hdmi_audio_board_and_dp1(self) -> None:
        raw = (
            'hl.monitor({ output = "DP-1", mode = "1920x1080@144" })\n'
            'hl.monitor({ output = "HDMI-A-1", mode = "640x480@60", mirror = "DP-1" })\n'
        )
        out = sanitize_text("hypr/confs/monitor.lua", raw, self.src_home)
        self.assertNotIn("HDMI-A-1", out)
        self.assertNotIn("DP-1", out)
        self.assertIn('output   = ""', out)
        self.assertIn('mode     = "preferred"', out)

    def test_keyboard_lua_removes_default_monitor(self) -> None:
        raw = (
            "hl.config({\n"
            "    cursor = {\n"
            '        default_monitor = "DP-1",\n'
            "    },\n"
            "})\n"
        )
        out = sanitize_text("hypr/confs/keyboard.lua", raw, self.src_home)
        self.assertNotIn("default_monitor", out)
        self.assertNotIn("DP-1", out)
        self.assertIn("cursor = {", out)

    def test_windowrules_lua_removes_dp1_workspace_mapping_only(self) -> None:
        raw = (
            'hl.window_rule({ name = "ses", match = { class = "pavucontrol" }, float = true })\n\n'
            "-- WORKSPACE OUTPUT MAPPING -- All workspaces routed to DP-1\n"
            "for i = 1, 10 do\n"
            "    hl.workspace_rule({\n"
            "        workspace = tostring(i),\n"
            '        monitor   = "DP-1",\n'
            "    })\n"
            "end\n\n"
            "hl.workspace_rule({\n"
            '    workspace = "special:magic",\n'
            '    monitor   = "DP-1",\n'
            "})\n\n"
            'hl.window_rule({ name = "LocalSend", float = true })\n'
        )
        out = sanitize_text("hypr/confs/windowrules.lua", raw, self.src_home)
        self.assertNotIn("DP-1", out)
        self.assertNotIn("workspace_rule", out)
        self.assertIn("pavucontrol", out)
        self.assertIn("LocalSend", out)

    def test_startup_lua_removes_audio_restore_and_guards_hyprglass(self) -> None:
        raw = (
            'hl.on("hyprland.start", function ()\n'
            '  hl.exec_cmd("hyprctl plugin load /home/eymen/.local/share/hyprglass/hyprglass.so")\n'
            '  hl.exec_cmd("/home/eymen/.config/hypr/scripts/apply_wallpaper.sh")\n'
            '  hl.exec_cmd("/home/eymen/.config/hypr/scripts/audio-restore.sh")\n'
            "end)\n"
        )
        out = sanitize_text("hypr/confs/startup.lua", raw, self.src_home)
        self.assertNotIn("audio-restore.sh", out)
        self.assertNotIn("/home/eymen", out)
        self.assertIn("io.open(hyprglass_so", out)
        self.assertIn("{{HOME}}/.config/hypr/scripts/apply_wallpaper.sh", out)

    def test_env_lua_nvidia_toggle(self) -> None:
        raw = (
            'hl.env("XDG_SESSION_TYPE", "wayland")\n\n'
            "-- Nvidia\n"
            'hl.env("GBM_BACKEND", "nvidia-drm")\n'
            'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")\n'
        )
        sanitized = sanitize_text("hypr/confs/env.lua", raw, self.src_home)
        self.assertIn(NVIDIA_ENV_MARKER, sanitized)
        self.assertNotIn("nvidia-drm", sanitized)

        with_nv = render_text("hypr/confs/env.lua", sanitized, self.dst_home, has_nvidia=True)
        self.assertIn('hl.env("GBM_BACKEND", "nvidia-drm")', with_nv)
        self.assertNotIn(NVIDIA_ENV_MARKER, with_nv)

        without_nv = render_text("hypr/confs/env.lua", sanitized, self.dst_home, has_nvidia=False)
        self.assertNotIn("nvidia-drm", without_nv)
        self.assertNotIn(NVIDIA_ENV_MARKER, without_nv)

    def test_user_dirs_and_home_replacement(self) -> None:
        raw = 'DIR="/home/eymen/Resimler/Arkaplan"\nFILE="/home/eymen/.config/fastfetch/logo.txt"\n'
        sanitized = sanitize_text("hypr/scripts/list_wallpapers.sh", raw, self.src_home)
        self.assertNotIn("/home/eymen", sanitized)
        self.assertIn("xdg-user-dir PICTURES", sanitized)
        self.assertIn("{{HOME}}/.config/fastfetch/logo.txt", sanitized)

        rendered = render_text(
            "hypr/scripts/list_wallpapers.sh", sanitized, self.dst_home, has_nvidia=False
        )
        self.assertIn("/home/alice/.config/fastfetch/logo.txt", rendered)


if __name__ == "__main__":
    unittest.main()
