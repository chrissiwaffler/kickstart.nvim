return {
  'stevearc/aerial.nvim',
  config = function()
    require('aerial').setup {
      layout = {
        default_direction = 'prefer_right',
        width = 40,
      },

      -- icons und guides für bessere struktur
      show_guides = true,
      guides = {
        mid_item = '├─',
        last_item = '└─',
        nested_top = '│ ',
        whitespace = '  ',
      },

      highlight_closest = true,
      highlight_mode = 'split_width',
      highlight_on_hover = true,
      highlight_on_jump = 300, -- ms delay nach jump

      keymaps = {
        ['gd'] = 'actions.jump', -- add gd for go-to
        ['gs'] = 'actions.jump_vsplit', -- split jump
      },

      attach_mode = 'global',

      -- update bei focus change
      update_events = 'CursorMoved,CursorMovedI',

      -- layout settings
      layout = {
        default_direction = 'prefer_right',
        preserve_equality = false, -- wichtig für splits!
      },
    }

    -- aerial keybinds
    vim.keymap.set('n', '<leader>oo', '<cmd>AerialToggle!<CR>', { desc = 'outline toggle' })
    vim.keymap.set('n', '<leader>on', '<cmd>AerialNext<CR>', { desc = 'outline next' })
    vim.keymap.set('n', '<leader>op', '<cmd>AerialPrev<CR>', { desc = 'outline prev' })
    vim.keymap.set('n', '<leader>os', '<cmd>Telescope aerial<CR>', { desc = 'outline search' })

    -- optional: jump to start/end
    vim.keymap.set('n', '<leader>ok', '<cmd>AerialPrevUp<CR>', { desc = 'outline up/parent' })
    vim.keymap.set('n', '<leader>oj', '<cmd>AerialNextUp<CR>', { desc = 'outline down/next parent' })

    -- change highlight color
    vim.api.nvim_set_hl(0, 'AerialLine', { bg = '#4a4a4a', fg = '#e5c07b', bold = true })
  end,
}
