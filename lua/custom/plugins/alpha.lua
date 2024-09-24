return {
  'goolord/alpha-nvim',
  event = 'VimEnter',
  opts = function()
    local dashboard = require 'alpha.themes.dashboard'
    require 'alpha.term'
    dashboard.section.terminal.command = vim.fn.stdpath 'config' .. '/start_image/blue-eyes -c'

    dashboard.section.terminal.width = 60
    dashboard.section.terminal.height = 24
    dashboard.section.terminal.opts.redraw = true
    dashboard.section.terminal.opts.window_config.zindex = 1
    -- offset placment for screenshots
    -- dashboard.section.terminal.opts.window_config.col = math.floor((vim.o.columns - 70) / 2 + 20)
    -- vim.cmd [[autocmd! User AlphaClosed]]

    -- custom button function with less vertical padding
    local function button(sc, txt, keybind, keybind_opts)
      local b = dashboard.button(sc, txt, keybind, keybind_opts)
      b.opts.hl = 'Normal'
      b.opts.hl_shortcut = 'Function'
      return b
    end

    dashboard.section.buttons.val = {
      button('i', '    new file', ':ene <BAR> startinsert<CR>'),
      button('o', '    old files', ':Telescope oldfiles<CR>'),
      button('f', '󰥨    find file', ':Telescope file_browser<CR>'),
      button('g', '󰱼    find text', ':Telescope live_grep_args<CR>'),
      button('h', '    browse git', ':Flog<CR>'),
      button('l', '󰒲    lazy', ':Lazy<CR>'),
      button('m', '󱌣    mason', ':Mason<CR>'),
      button('p', '󰄉    profile', ':Lazy profile<CR>'),
      button('q', '󰭿    quit', ':qa<CR>'),
    }
    -- for _, button in ipairs(dashboard.section.buttons.val) do
    --   button.opts.hl = 'Normal'
    --   button.opts.hl_shortcut = 'Function'
    -- end
    dashboard.section.footer.opts.hl = 'Special'

    dashboard.opts.layout = {
      { type = 'padding', val = 1 },
      dashboard.section.terminal,
      { type = 'padding', val = 1 },
      dashboard.section.buttons,
      dashboard.section.footer,
    }

    -- test, remove later
    -- dashboard.section.buttons.opts.spacing = 0
    return dashboard
  end,
  config = function(_, dashboard)
    -- close lazy and re-open when the dashboard is ready
    if vim.o.filetype == 'lazy' then
      vim.cmd.close()
      vim.api.nvim_create_autocmd('User', {
        pattern = 'AlphaReady',
        callback = function()
          require('lazy').show()
        end,
      })
    end
    require('alpha').setup(dashboard.opts)

    vim.api.nvim_create_autocmd('User', {
      pattern = 'LazyVimStarted',
      callback = function()
        local stats = require('lazy').stats()
        local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
        dashboard.section.footer.val = '󱐋 ' .. stats.count .. ' plugins loaded in ' .. ms .. 'ms'
        pcall(vim.cmd.AlphaRedraw)
      end,
    })
  end,
}
