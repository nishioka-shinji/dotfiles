-- leader は lazy.nvim の読み込み前に決める必要がある
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- :help を日本語 -> 英語の順に引く。ja が無い項目は英語版へフォールバックする
vim.opt.helplang = "ja,en"

-- lualine の配色に必要
vim.opt.termguicolors = true

-- lazy.nvim を未導入なら clone する
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "lazy.nvim の clone に失敗しました:\n", "ErrorMsg" },
      { out, "WarningMsg" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- lua/plugins/ 配下の各ファイルが 1 プラグインの設定に対応する
require("lazy").setup({
  spec = { { import = "plugins" } },
  install = { colorscheme = { "habamax" } },
  -- 更新の有無だけ確認する。notify を切り、:Lazy の UI 側で気づく運用にする
  checker = { enabled = true, notify = false },
})
