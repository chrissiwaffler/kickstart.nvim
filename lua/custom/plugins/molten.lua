-- molten.nvim: jupyter kernel + inline outputs in neovim (löst iron.nvim python-REPL ab)
-- nix-deps (dotfiles modules/base/neovim.nix):
--   extraPython3Packages = [ pynvim jupyter-client nbformat ]
--   extraLuaPackages     = [ magick ]   (image.nvim)
return {
  {
    '3rd/image.nvim',
    version = '1.*',
    lazy = true, -- wird von molten geladen
    opts = {
      backend = 'kitty',
      integrations = {}, -- molten rendert die images selbst
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
      window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', '' },
    },
  },
  {
    'benlubas/molten-nvim',
    version = '^1.9.0',
    build = ':UpdateRemotePlugins',
    dependencies = { '3rd/image.nvim' },
    lazy = false,
    init = function()
      vim.g.molten_image_provider = 'image.nvim'
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_lines_off_by_1 = true
      vim.g.molten_wrap_output = true
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_save_path = vim.fn.stdpath 'data' .. '/molten'
    end,
    config = function()
      -- # %% zellgrenzen (hydrogen/jupytext-stil, 1-indiziert, inklusiv)
      local cell_bounds = function()
        local cur = vim.api.nvim_win_get_cursor(0)[1]
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        if #lines == 0 then
          return cur, cur
        end
        local s = 1
        for i = cur, 1, -1 do
          if lines[i]:match '^# %%' then
            s = i + 1
            break
          end
        end
        local e = #lines
        for i = cur + 1, #lines do
          if lines[i]:match '^# %%' then
            e = i - 1
            break
          end
        end
        if s > e then
          e = math.min(s, #lines)
          s = math.min(s, e)
        end
        return s, e
      end

      local cell_ranges = function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local delims = {}
        for i, l in ipairs(lines) do
          if l:match '^# %%' then
            table.insert(delims, i)
          end
        end
        local ranges = {}
        for c = 1, #delims do
          local s = delims[c] + 1
          local e = (c < #delims) and (delims[c + 1] - 1) or #lines
          if s <= e then
            table.insert(ranges, { s, e })
          end
        end
        if #ranges == 0 and #lines > 0 then
          ranges = { { 1, #lines } }
        end
        return ranges
      end

      -- bereich als molten-cell ausführen (fake-visual setzt '< '> marks)
      local eval_lines = function(s, e)
        if s > e then
          return
        end
        vim.cmd.normal { string.format('%dGV%dG', s, e), bang = true }
        vim.cmd 'MoltenEvaluateVisual'
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
      end

      local restore_cursor = function(cb)
        local cur = vim.api.nvim_win_get_cursor(0)
        cb()
        pcall(vim.api.nvim_win_set_cursor, 0, cur)
      end

      local run_cell = function()
        restore_cursor(function()
          local s, e = cell_bounds()
          eval_lines(s, e)
        end)
      end

      local run_cell_and_next = function()
        run_cell()
        vim.fn.search('^# %%', 'W')
      end

      local run_all = function()
        restore_cursor(function()
          for _, r in ipairs(cell_ranges()) do
            eval_lines(r[1], r[2])
          end
        end)
      end

      local run_above = function()
        local cur = vim.api.nvim_win_get_cursor(0)[1]
        restore_cursor(function()
          for _, r in ipairs(cell_ranges()) do
            if r[2] <= cur then
              eval_lines(r[1], r[2])
            end
          end
          -- aktuelle zelle inklusive
          local s, e = cell_bounds()
          eval_lines(s, e)
        end)
      end

      -- variable-inspector (output als virt-text unter der zeile)
      local inspect_var = function()
        local word = vim.fn.expand '<cword>'
        if word == '' then
          return
        end
        local code = string.format('print(f"[DEBUG] %s = {%s!r} (type: {type(%s).__name__})")', word, word, word)
        vim.fn.MoltenEvaluateArgument(code)
      end

      local map = function(lhs, rhs, desc, mode)
        vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc, silent = true })
      end

      -- kernel
      map('<leader>ii', ':MoltenInit<CR>', 'Init kernel')
      map('<leader>ir', ':MoltenInfo<CR>', 'Molten info')
      map('<leader>irn', ':MoltenRestart!<CR>', 'Nuclear kernel restart')
      map('<leader>is<Space>', ':MoltenInterrupt<CR>', 'Interrupt kernel')

      -- execution (iron muscle memory)
      map('<leader>ie', run_cell, 'Execute cell')
      map('<leader>isb', run_cell, 'Execute cell')
      map('<leader>ien', run_cell_and_next, 'Execute cell + jump next')
      map('<leader>isl', ':MoltenEvaluateLine<CR>', 'Execute line')
      map('<leader>isc', ':MoltenEvaluateOperator<CR>', 'Evaluate operator')
      map('<leader>isc', ':<C-u>MoltenEvaluateVisual<CR>gv', 'Execute selection', 'v')
      map('<leader>iaa', run_all, 'Execute all cells')
      map('<leader>iau', run_above, 'Execute all cells up to current')

      -- navigation
      map('<leader>ij', function()
        vim.fn.search('^# %%', 'W')
      end, 'Jump to next cell')
      map('<leader>ik', function()
        vim.fn.search('^# %%', 'bW')
      end, 'Jump to previous cell')

      -- outputs
      map('<leader>ios', ':noautocmd MoltenEnterOutput<CR>', 'Open output window')
      map('<leader>ioh', ':MoltenHideOutput<CR>', 'Hide output window')
      map('<leader>imd', ':MoltenDelete<CR>', 'Delete cell output')
      map('<leader>iv', inspect_var, 'Inspect variable under cursor')

      -- leere, valide .ipynb anlegen (jupytext braucht valides format)
      local default_notebook = [[{
  "cells": [
   {
    "cell_type": "markdown",
    "metadata": {},
    "source": [""]
   }
  ],
  "metadata": {
   "kernelspec": {
    "display_name": "Python 3",
    "language": "python",
    "name": "python3"
   },
   "language_info": {
    "codemirror_mode": {"name": "ipython"},
    "file_extension": ".py",
    "mimetype": "text/x-python",
    "name": "python",
    "nbconvert_exporter": "python",
    "pygments_lexer": "ipython3"
   }
  },
  "nbformat": 4,
  "nbformat_minor": 5
}]]
      vim.api.nvim_create_user_command('NewNotebook', function(opts)
        local path = opts.args .. '.ipynb'
        local file = io.open(path, 'w')
        if file then
          file:write(default_notebook)
          file:close()
          vim.cmd('edit ' .. path)
        else
          vim.notify('NewNotebook: cannot write ' .. path, vim.log.levels.ERROR)
        end
      end, { nargs = 1, complete = 'file' })

      -- beim ipynb-öffnen: passenden kernel init + outputs importieren
      local imb = function(e)
        vim.schedule(function()
          local kernels = vim.fn.MoltenAvailableKernels and vim.fn.MoltenAvailableKernels() or {}
          local kernel_name = nil
          local ok, meta = pcall(function()
            return vim.json.decode(io.open(e.file, 'r'):read 'a').metadata.kernelspec.name
          end)
          if ok and vim.tbl_contains(kernels, meta) then
            kernel_name = meta
          else
            local venv = os.getenv 'VIRTUAL_ENV' or os.getenv 'CONDA_PREFIX'
            if venv then
              local cand = string.match(venv, '/.+/(.+)')
              if vim.tbl_contains(kernels, cand) then
                kernel_name = cand
              end
            end
          end
          if kernel_name then
            vim.cmd(('MoltenInit %s'):format(kernel_name))
          end
          vim.cmd 'MoltenImportOutput'
        end)
      end
      vim.api.nvim_create_autocmd('BufAdd', { pattern = '*.ipynb', callback = imb })
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.ipynb',
        callback = function(e)
          if vim.api.nvim_get_vvar 'vim_did_enter' ~= 1 then
            imb(e)
          end
        end,
      })

      -- beim speichern: outputs ins .ipynb zurückschreiben
      vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = '*.ipynb',
        callback = function()
          if require('molten.status').initialized() == 'Molten' then
            vim.cmd 'MoltenExportOutput!'
          end
        end,
      })

      -- in normalen .py-files: output im float statt virt-text (less noisy)
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.py',
        callback = function(e)
          if e.file:match '.otter.' then
            return
          end
          if require('molten.status').initialized() == 'Molten' then
            vim.fn.MoltenUpdateOption('virt_lines_off_by_1', false)
            vim.fn.MoltenUpdateOption('virt_text_output', false)
          else
            vim.g.molten_virt_lines_off_by_1 = false
            vim.g.molten_virt_text_output = false
          end
        end,
      })
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.ipynb',
        callback = function(e)
          if e.file:match '.otter.' then
            return
          end
          if require('molten.status').initialized() == 'Molten' then
            vim.fn.MoltenUpdateOption('virt_lines_off_by_1', true)
            vim.fn.MoltenUpdateOption('virt_text_output', true)
          else
            vim.g.molten_virt_lines_off_by_1 = true
            vim.g.molten_virt_text_output = true
          end
        end,
      })

      local ok, wk = pcall(require, 'which-key')
      if ok then
        wk.add { { '<leader>i', group = '[I]Python / Molten' } }
      end
    end,
  },
}
