"""Sanitization (export) and rendering (install) rules for portable dotfiles."""

from __future__ import annotations

import re
from pathlib import Path

NVIDIA_ENV_MARKER = "-- {{NVIDIA_ENV_BLOCK}}"
NVIDIA_ENV_BLOCK = (
    "-- Nvidia\n"
    'hl.env("GBM_BACKEND", "nvidia-drm")\n'
    'hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")'
)

GENERIC_MONITOR_LUA = """-- Otomatik monitör algılama (çoklu monitör için kendi çıkış adlarınızı ekleyin)
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "auto",
})
"""


def _sanitize_monitor_lua(_content: str) -> str:
    return GENERIC_MONITOR_LUA


def _sanitize_keyboard_lua(content: str) -> str:
    # Remove hardcoded default_monitor = "DP-1" (or any output name)
    return re.sub(
        r'^[ \t]*default_monitor\s*=\s*"[^"]*",?[ \t]*\r?\n',
        "",
        content,
        flags=re.MULTILINE,
    )


def _sanitize_windowrules_lua(content: str) -> str:
    # Remove workspace output mapping block routing all workspaces to DP-1
    pattern = re.compile(
        r"\n*-- WORKSPACE OUTPUT MAPPING[^\n]*\n"
        r"for\s+i\s*=\s*1,\s*10\s+do\s*\n"
        r".*?hl\.workspace_rule\(\{.*?\}\)\s*\n"
        r"end\s*\n"
        r"(?:\s*hl\.workspace_rule\(\{[^}]*special:magic[^}]*\}\)\s*\n)?",
        re.DOTALL,
    )
    cleaned = pattern.sub("\n", content)
    # Fallback: remove any remaining workspace_rule blocks pinned to a specific monitor
    cleaned = re.sub(
        r'hl\.workspace_rule\(\{\s*workspace\s*=\s*"[^"]+",\s*monitor\s*=\s*"[^"]+",?\s*\}\)\s*\n?',
        "",
        cleaned,
    )
    return cleaned


def _sanitize_startup_lua(content: str) -> str:
    # Remove audio-restore.sh invocation (system-specific HDMI audio card)
    cleaned = re.sub(
        r'^[ \t]*hl\.exec_cmd\("[^"]*audio-restore\.sh[^"]*"\)[ \t]*(?:--[^\n]*)?\r?\n',
        "",
        content,
        flags=re.MULTILINE,
    )
    # Make hyprglass.so plugin load conditional so it doesn't fail when absent
    cleaned = re.sub(
        r'^([ \t]*)hl\.exec_cmd\("hyprctl plugin load ([^"]+hyprglass\.so)"\)[ \t]*$',
        (
            r'\1local hyprglass_so = "\2"\n'
            r'\1local f = io.open(hyprglass_so, "r")\n'
            r"\1if f then\n"
            r"\1  f:close()\n"
            r'\1  hl.exec_cmd("hyprctl plugin load " .. hyprglass_so)\n'
            r"\1end"
        ),
        cleaned,
        flags=re.MULTILINE,
    )
    return cleaned


def _sanitize_env_lua(content: str) -> str:
    pattern = re.compile(
        r"(?:--\s*Nvidia[^\n]*\r?\n)?"
        r'(?:[ \t]*hl\.env\("GBM_BACKEND",\s*"nvidia-drm"\)[ \t]*\r?\n)?'
        r'(?:[ \t]*hl\.env\("__GLX_VENDOR_LIBRARY_NAME",\s*"nvidia"\)[ \t]*\r?\n)?',
        re.IGNORECASE,
    )

    def _repl(match: re.Match[str]) -> str:
        if match.group(0).strip():
            return f"{NVIDIA_ENV_MARKER}\n"
        return ""

    cleaned = pattern.sub(_repl, content)
    if NVIDIA_ENV_MARKER not in cleaned:
        cleaned = cleaned.rstrip() + f"\n\n{NVIDIA_ENV_MARKER}\n"
    return cleaned


def _sanitize_user_dirs(content: str, source_home: str) -> str:
    escaped_home = re.escape(source_home)
    content = re.sub(
        rf"{escaped_home}/Resimler/Arkaplan",
        '$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers',
        content,
    )
    content = re.sub(
        rf"{escaped_home}/Resimler/Ekran Görüntüleri",
        '$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots',
        content,
    )
    return content


def sanitize_text(rel_path: str, content: str, source_home: Path) -> str:
    """Apply path-specific and global sanitization rules for export."""
    home_str = str(source_home).rstrip("/")

    if rel_path == "hypr/confs/monitor.lua":
        content = _sanitize_monitor_lua(content)
    elif rel_path == "hypr/confs/keyboard.lua":
        content = _sanitize_keyboard_lua(content)
    elif rel_path == "hypr/confs/windowrules.lua":
        content = _sanitize_windowrules_lua(content)
    elif rel_path == "hypr/confs/startup.lua":
        content = _sanitize_startup_lua(content)
    elif rel_path == "hypr/confs/env.lua":
        content = _sanitize_env_lua(content)
    elif rel_path == "hypr/vars/bg":
        content = re.sub(
            rf"{re.escape(home_str)}/Resimler/Arkaplan",
            "{{WALLPAPERS_DIR}}",
            content,
        )

    content = _sanitize_user_dirs(content, home_str)
    content = content.replace(home_str, "{{HOME}}")
    return content


def render_text(
    rel_path: str,
    content: str,
    target_home: Path,
    has_nvidia: bool,
    wallpapers_dir: Path | None = None,
) -> str:
    """Render sanitized template text for installation on a target machine."""
    home_str = str(target_home).rstrip("/")
    wp_dir_str = str(wallpapers_dir or (target_home / "Pictures" / "Wallpapers")).rstrip("/")

    if rel_path == "hypr/confs/env.lua":
        if has_nvidia:
            content = content.replace(NVIDIA_ENV_MARKER, NVIDIA_ENV_BLOCK)
        else:
            content = re.sub(
                rf"\n?{re.escape(NVIDIA_ENV_MARKER)}\r?\n?",
                "\n",
                content,
            )

    content = content.replace("{{WALLPAPERS_DIR}}", wp_dir_str)
    content = content.replace("{{HOME}}", home_str)
    return content
