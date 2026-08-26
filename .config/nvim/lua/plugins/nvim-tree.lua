-- ファイルツリー。netrw と競合するため無効化が必須
return {
  "nvim-tree/nvim-tree.lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "ファイルツリーの開閉" },
    { "<leader>f", "<cmd>NvimTreeFindFile<cr>", desc = "現在のファイルをツリー上で表示" },
  },
  init = function()
    vim.g.loaded_netrw = 1
    vim.g.loaded_netrwPlugin = 1
  end,
  opts = {
    view = { width = 35 },
    renderer = { group_empty = true },
    filters = { dotfiles = false },
  },
}
