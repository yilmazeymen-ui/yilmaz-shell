import unittest
from types import SimpleNamespace
from unittest.mock import patch

from hyprdots_cli.packages import find_missing_packages, prompt_and_install_packages


class PackagesTests(unittest.TestCase):
    @patch("hyprdots_cli.packages.get_installed_packages", return_value={"hyprland", "kitty"})
    def test_find_missing_packages(self, _mock_installed) -> None:
        pac, aur = find_missing_packages(["hyprland", "kitty", "cava"], ["wayscriber-bin"])
        self.assertEqual(pac, ["cava"])
        self.assertEqual(aur, ["wayscriber-bin"])

    @patch("hyprdots_cli.packages.subprocess.run")
    @patch("hyprdots_cli.packages.find_missing_packages", return_value=(["cava"], ["wayscriber-bin"]))
    @patch("hyprdots_cli.packages.sys.stdin")
    @patch("builtins.input", return_value="h")
    def test_prompt_declined_does_not_install(
        self, _mock_input, mock_stdin, _mock_missing, mock_run
    ) -> None:
        mock_stdin.isatty.return_value = True
        ok = prompt_and_install_packages(["cava"], ["wayscriber-bin"])
        self.assertTrue(ok)
        mock_run.assert_not_called()

    @patch("hyprdots_cli.packages.detect_aur_helper", return_value="yay")
    @patch("hyprdots_cli.packages.subprocess.run", return_value=SimpleNamespace(returncode=0))
    @patch("hyprdots_cli.packages.find_missing_packages", return_value=(["cava"], ["wayscriber-bin"]))
    @patch("hyprdots_cli.packages.sys.stdin")
    @patch("builtins.input", return_value="e")
    def test_prompt_accepted_installs_pacman_and_aur(
        self, _mock_input, mock_stdin, _mock_missing, mock_run, _mock_aur
    ) -> None:
        mock_stdin.isatty.return_value = True
        ok = prompt_and_install_packages(["cava"], ["wayscriber-bin"])
        self.assertTrue(ok)
        self.assertEqual(mock_run.call_count, 2)
        self.assertEqual(
            mock_run.call_args_list[0].args[0],
            ["sudo", "pacman", "-S", "--needed", "cava"],
        )
        self.assertEqual(
            mock_run.call_args_list[1].args[0],
            ["yay", "-S", "--needed", "wayscriber-bin"],
        )


if __name__ == "__main__":
    unittest.main()
