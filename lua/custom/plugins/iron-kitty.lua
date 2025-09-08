return {
  {
    'Vigemus/iron.nvim',
    config = function()
      local iron = require 'iron.core'

      iron.setup {
        config = {
          -- Whether a repl should be discarded or not
          scratch_repl = true,
          -- Your repl definitions come here
          repl_definition = {
            python = {
              -- Use ipython with specific options for better experience
              command = { 'ipython', '--no-autoindent', '--colors=Linux', '--TerminalInteractiveShell.confirm_exit=False' },
              -- Format for sending code (bracketed paste for multi-line)
              format = require('iron.fts.common').bracketed_paste_python,
              -- IMPORTANT: This tells iron to recognize # %% as cell dividers
              -- This is what makes <leader>isb and <leader>ie work with cells!
              block_dividers = { '# %%', '#%%' },
            },
          },
          -- How the repl window will be displayed
          -- Use vim command directly for a proper split
          repl_open_cmd = 'vertical botright 80 split',

          -- Alternative using iron's view helpers (should also work):
          -- repl_open_cmd = require('iron.view').split.vertical.botright(80),
          -- repl_open_cmd = require('iron.view').right(40),

          -- If the repl buffer is listed
          buflisted = false,
        },
        -- Keymaps configuration
        keymaps = {
          send_motion = '<leader>isc',
          visual_send = '<leader>isc',
          send_file = '<leader>isf',
          send_line = '<leader>isl',
          send_paragraph = '<leader>isp',
          send_until_cursor = '<leader>isu',
          send_mark = '<leader>ism',
          send_code_block = '<leader>isb', -- Sends # %% blocks!
          send_code_block_and_move = '<leader>isn',
          mark_motion = '<leader>imc',
          mark_visual = '<leader>imc',
          remove_mark = '<leader>imd',
          cr = '<leader>is<cr>',
          interrupt = '<leader>is<space>',
          exit = '<leader>isq',
          clear = '<leader>icl',
        },
        -- If the highlight is on, you can change how it looks
        highlight = {
          italic = true,
        },
        ignore_blank_lines = true,
      }

      -- Additional custom keymaps
      -- Since we already have send_code_block mapped to <leader>isb,
      -- let's make <leader>ie an alias for convenience
      vim.keymap.set('n', '<leader>ie', '<leader>isb', { desc = 'Execute current cell', remap = true })

      -- Quick line execution (override the default to make it simpler)
      vim.keymap.set('n', '<leader>il', '<leader>isl', { desc = 'Execute current line', remap = true })

      vim.keymap.set('n', '<leader>iaa', function()
        -- Execute entire buffer
        local iron = require 'iron.core'
        local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
        iron.send(nil, content)
      end, { desc = 'Execute all cells' })

      vim.keymap.set('n', '<leader>iau', function()
        local iron = require 'iron.core'
        local current_line = vim.fn.line '.'
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

        -- find current cell end
        local cell_end = current_line
        for i = current_line, #lines do
          if lines[i] and lines[i]:match '^# %%' and i > current_line then
            cell_end = i - 1
            break
          end
          cell_end = i
        end

        -- grab everything from start to current cell end
        local content = table.concat(vim.api.nvim_buf_get_lines(0, 0, cell_end, false), '\n')
        iron.send(nil, content)
      end, { desc = 'Execute all cells up to current' })

      -- jump to next/previous cell (wie in jupyter mit shift+enter vibes)
      vim.keymap.set('n', '<leader>ij', function()
        vim.fn.search('^# %%', 'W')
      end, { desc = 'Jump to next cell' })

      vim.keymap.set('n', '<leader>ik', function()
        vim.fn.search('^# %%', 'bW')
      end, { desc = 'Jump to previous cell' })

      -- execute cell and jump to next (jupyter muscle memory ftw)
      -- vim.keymap.set('n', '<leader>ien', function()
      --   vim.cmd 'normal! <leader>isb' -- execute current cell
      --   vim.fn.search('^# %%', 'W') -- jump to next
      -- end, { desc = 'Execute cell and go next' })
      vim.keymap.set('n', '<leader>ien', function()
        -- use iron's actual send_code_block function
        require('iron.core').send_code_block()
        vim.defer_fn(function()
          vim.fn.search('^# %%', 'W')
        end, 50)
      end, { desc = 'Execute cell and go next' })

      -- clear output and restart fresh
      vim.keymap.set('n', '<leader>irn', function()
        vim.cmd 'IronRestart'
        vim.notify('repl fresh af', vim.log.levels.INFO)
      end, { desc = 'Nuclear restart' })

      -- variable inspector (with type output)
      vim.keymap.set('n', '<leader>iv', function()
        local word = vim.fn.expand '<cword>'
        if word and word ~= '' then
          local cmd = string.format(
            [[
try:
    print(f"[DEBUG] %s = {%s} (type: {type(%s).__name__})")
except Exception as e:
    try:
        print(f"[DEBUG] %s exists: {%s in locals() or %s in globals()}")
    except:
        print(f"[DEBUG] '%s' - error: {e}")
]],
            word,
            word,
            word,
            word,
            word,
            word,
            word
          )
          require('iron.core').send(nil, cmd)
        end
      end, { desc = 'Inspect variable under cursor' })

      vim.keymap.set('n', '<leader>ii', '<leader>is<space>', { desc = 'Interrupt execution', remap = true })

      -- You can also use the original iron keymaps:
      -- <leader>isc - send motion/visual selection
      -- <leader>isb - send code block (between # %% markers)
      -- <leader>isl - send line
      -- <leader>isp - send paragraph
      -- <leader>isn - send code block and move to next

      -- Note: If you get "No range allowed" errors, make sure you're using
      -- the keymaps above, not trying to use ranges with :IronSend
    end,
    keys = {
      -- REPL management
      { '<leader>irs', '<cmd>IronRepl<cr>', desc = 'Start REPL' },
      { '<leader>irr', '<cmd>IronRestart<cr>', desc = 'Restart REPL' },
      { '<leader>irh', '<cmd>IronHide<cr>', desc = 'Hide REPL' },
      { '<leader>irf', '<cmd>IronFocus<cr>', desc = 'Focus REPL' },
      { '<leader>irR', '<cmd>IronRestart<cr>', desc = 'Force restart REPL' },
    },
  },

  -- Which-key integration for better keybind discovery
  {
    'folke/which-key.nvim',
    config = function()
      local wk = require 'which-key'
      wk.add {
        { '<leader>i', group = 'iron/interactive' },
        { '<leader>ir', group = 'repl' },
        { '<leader>is', group = 'send' },
        { '<leader>im', group = 'mark' },
      }
    end,
  },
}
