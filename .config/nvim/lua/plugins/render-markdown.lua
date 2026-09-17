-- markdown をバッファ内で装飾表示する。
-- markdown / markdown_inline の treesitter パーサーは Neovim 同梱のものを使う
return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  ft = { "markdown" },
  opts = {
    -- html / latex / yaml はパーサー未導入のため無効化する
    html = { enabled = false },
    latex = { enabled = false },
    yaml = { enabled = false },
  },
  keys = {
    { "<leader>m", "<cmd>RenderMarkdown toggle<cr>", desc = "markdown 装飾表示の切替", ft = "markdown" },
  },
}
