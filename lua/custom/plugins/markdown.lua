-- markdown-rendering: render-markdown.nvim (anti-conceal hybrid in normal md-
-- buffern; rendert den notebook-reader-float aus molten.lua). treesitter-parser
-- markdown/markdown_inline/html sind via init.lua installiert, icons kommen von
-- mini.nvim/nvim-web-devicons
return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    ft = 'markdown', -- lazy: lädt wenn ein markdown-ft buffer auftaucht
    opts = {},
  },
}
