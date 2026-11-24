local M = {}

M.apps = {
  terminal    = "kitty",
  fileManager = "dolphin",
  menu        = "quickshell -c my-shell ipc call menu openLauncher",
  browser     = "zen-browser"
}

M.deco = {
  gapsIn     = 5,
  gapsOut    = 10,
  borderSize = 0,
  round      = 15,
  roundPwr   = 2,
  activeTrnp = 1,
  inactvTrnp = 0.95,
  animSpd    = 1.2
}

return M
