"""Git branch and update operations for hyprdots."""

from __future__ import annotations

import subprocess
from pathlib import Path


class GitError(RuntimeError):
    """Raised when a git operation fails."""


def _run_git(repo_root: Path, *args: str) -> str:
    res = subprocess.run(
        ["git", "-C", str(repo_root), *args],
        capture_output=True,
        text=True,
        check=False,
    )
    if res.returncode != 0:
        msg = res.stderr.strip() or res.stdout.strip() or f"git {' '.join(args)} failed"
        raise GitError(msg)
    return res.stdout.strip()


def is_git_repo(repo_root: Path) -> bool:
    """Return True if repo_root is inside a git work tree."""
    res = subprocess.run(
        ["git", "-C", str(repo_root), "rev-parse", "--is-inside-work-tree"],
        capture_output=True,
        text=True,
        check=False,
    )
    return res.returncode == 0 and res.stdout.strip() == "true"


def current_branch(repo_root: Path) -> str:
    """Return the currently checked-out branch name (or HEAD)."""
    return _run_git(repo_root, "rev-parse", "--abbrev-ref", "HEAD")


def list_remote_branches(repo_root: Path, remote: str = "origin") -> list[str]:
    """Fetch remote refs and return available branch names."""
    _run_git(repo_root, "fetch", remote, "--prune")
    raw = _run_git(repo_root, "branch", "-r", "--format=%(refname:short)")
    prefix = f"{remote}/"
    branches: list[str] = []
    for line in raw.splitlines():
        name = line.strip()
        if not name or name.endswith("/HEAD"):
            continue
        if name.startswith(prefix):
            branches.append(name[len(prefix) :])
    return branches


def update_branch(repo_root: Path, branch: str | None = None, remote: str = "origin") -> str:
    """Fetch from remote, switch to branch if given, and fast-forward pull."""
    dirty = _run_git(repo_root, "status", "--porcelain")
    if dirty:
        raise GitError(
            "Repo dizininde commitlenmemiş değişiklikler var. "
            "Önce commit veya stash yapın:\n" + dirty
        )

    _run_git(repo_root, "fetch", remote, "--prune")
    target = branch or current_branch(repo_root)

    local_branches = set(
        line.strip()
        for line in _run_git(repo_root, "branch", "--format=%(refname:short)").splitlines()
        if line.strip()
    )
    if target in local_branches:
        _run_git(repo_root, "switch", target)
    else:
        _run_git(repo_root, "switch", "-c", target, "--track", f"{remote}/{target}")

    _run_git(repo_root, "pull", "--ff-only", remote, target)
    return target
