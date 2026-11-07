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
      vim.g.molten_auto_open_output = true -- output-fenster geht nach jedem run automatisch auf
      vim.g.molten_virt_text_output = false -- outputs im bordered float statt virt-text
      vim.g.molten_output_win_max_height = 20
      -- box-look: default-border ist nur ein ━ oben ohne seiten/unterkante
      vim.g.molten_output_win_border = 'rounded'
      vim.g.molten_output_crop_border = false -- untere kante bleibt sichtbar
      vim.g.molten_output_win_style = 'minimal' -- keine zeilennummern im output-float
      vim.g.molten_output_win_cover_gutter = false -- float startet am code, nicht überm gutter
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

      -- bereich als molten-cell ausführen — MoltenEvaluateRange direkt mit dem
      -- zeilen-span statt fake-visual: keine '< '>marks, kein visual-modus. fake-
      -- visual hing an marks, die beim ersten run einer session noch unset sind
      -- → molten: 'No visual selection found'
      local eval_lines = function(s, e)
        if s > e then
          return
        end
        vim.fn.MoltenEvaluateRange(s, e)
      end

      local run_cell = function()
        local s, e = cell_bounds()
        eval_lines(s, e)
      end

      local run_cell_and_next = function()
        run_cell()
        vim.fn.search('^# %%', 'W')
      end

      local run_all = function()
        for _, r in ipairs(cell_ranges()) do
          eval_lines(r[1], r[2])
        end
      end

      local run_above = function()
        local cur = vim.api.nvim_win_get_cursor(0)[1]
        for _, r in ipairs(cell_ranges()) do
          if r[2] <= cur then
            eval_lines(r[1], r[2])
          end
        end
        -- aktuelle zelle inklusive
        local s, e = cell_bounds()
        eval_lines(s, e)
      end

      -- variable-inspector (läuft durch den kernel, output als window wie jede zelle)
      local inspect_var = function()
        local word = vim.fn.expand '<cword>'
        if word == '' then
          return
        end
        local code = string.format('print(f"[DEBUG] %s = {%s!r} (type: {type(%s).__name__})")', word, word, word)
        vim.fn.MoltenEvaluateArgument(code)
      end

      -- venv-detection + automatische kernelspec-registrierung
      -- (ersetzt manuelles `python -m ipykernel install --user --name <projekt>`)
      local is_venv = function(dir)
        return dir ~= nil and vim.uv.fs_stat(dir .. '/bin/python') ~= nil
      end

      local path_hash = function(s)
        local h = 0
        for i = 1, #s do
          h = (h * 31 + s:byte(i)) % 65536
        end
        return string.format('%04x', h)
      end

      -- activation-äquivalent: $VIRTUAL_ENV/$CONDA_PREFIX, sonst aufwärts vom
      -- notebook bis git-root: erstes dir mit .venv|venv + bin/python drin
      local detect_venv = function(start_dir)
        local env = os.getenv 'VIRTUAL_ENV' or os.getenv 'CONDA_PREFIX'
        if env and is_venv(env) then
          return env
        end
        local dir = vim.fs.normalize(start_dir)
        local bound = vim.fs.root(dir, '.git') or vim.uv.os_homedir()
        while dir do
          for _, name in ipairs { '.venv', 'venv' } do
            local cand = dir .. '/' .. name
            if is_venv(cand) then
              return cand
            end
          end
          if dir == bound or dir == vim.fs.dirname(dir) then
            return nil
          end
          dir = vim.fs.dirname(dir)
        end
        return nil
      end

      local has_ipykernel = function(venv)
        return vim.fn.glob(venv .. '/lib/python3.*/site-packages/ipykernel/__init__.py') ~= ''
      end

      local kernels_dir = function()
        if vim.uv.os_uname().sysname == 'Darwin' then
          return vim.fn.expand '~/Library/Jupyter/kernels'
        end
        return vim.fn.expand '~/.local/share/jupyter/kernels'
      end

      -- schreibt kernel.json wie `ipykernel install --user` es täte (nur ohne logos).
      -- name = projekt-basename; kollision mit fremdem venv → `-<hash>`-suffix statt overwrite
      local ensure_spec = function(venv)
        local python = venv .. '/bin/python'
        local project = vim.fs.basename(vim.fs.dirname(venv))
        local name = project
        local spec_path = kernels_dir() .. '/' .. name .. '/kernel.json'
        if vim.uv.fs_stat(spec_path) then
          local file = io.open(spec_path, 'r')
          local ok, existing = pcall(function()
            return vim.json.decode(file:read 'a')
          end)
          if ok and existing and existing.argv and existing.argv[1] == python then
            return name -- gleiche venv → idempotent
          end
          name = project .. '-' .. path_hash(python)
          spec_path = kernels_dir() .. '/' .. name .. '/kernel.json'
        end
        vim.fn.mkdir(vim.fs.dirname(spec_path), 'p')
        local file = io.open(spec_path, 'w')
        if not file then
          vim.notify('molten: cannot write ' .. spec_path, vim.log.levels.ERROR)
          return nil
        end
        file:write(vim.json.encode {
          argv = { python, '-m', 'ipykernel_launcher', '-f', '{connection_file}' },
          display_name = 'Python (' .. project .. ')',
          language = 'python',
        })
        file:close()
        return name
      end

      -- kernel am aktuellen buffer attached? (MoltenStatusLineInit/.initialized()
      -- heißt nur 'plugin geladen', nicht 'kernel läuft' → hier ungeeignet)
      local kernel_attached = function()
        local ok, kernels = pcall(vim.fn.MoltenRunningKernels, true)
        return ok and type(kernels) == 'table' and #kernels > 0
      end

      -- smart-init: venv finden → spec sicherstellen → kernel starten
      local smart_init = function()
        if vim.fn.exists ':MoltenInit' ~= 2 then
          vim.notify 'Molten: remote plugin not registered yet — restart nvim after :Lazy sync'
          return
        end
        if kernel_attached() then
          vim.notify 'molten: kernel already running'
          return
        end
        local venv = detect_venv(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
        if not venv then
          vim.cmd 'MoltenInit' -- kein venv → molten's eigener picker
          return
        end
        if not has_ipykernel(venv) then
          vim.notify('molten: no ipykernel in ' .. venv .. ' — run: uv pip install ipykernel', vim.log.levels.WARN)
          return
        end
        local name = ensure_spec(venv)
        if name then
          vim.cmd { cmd = 'MoltenInit', args = { name } }
        end
      end

      -- cell-grenzen sichtbar machen: vollbreites band auf jeder `# %%`-marker-zeile
      -- (extmarks hängen an positionen und wandern mit edits) + marker-text bold/blue
      -- via syn match (buffer-lokal, zero-maintenance)
      local band_ns = vim.api.nvim_create_namespace 'molten_cell_bands'

      local hex_blend = function(hex, other, alpha)
        local ch = function(s, i)
          return tonumber(s:sub(i, i + 1), 16) or 0
        end
        local mix = function(a, b)
          return math.floor(a + (b - a) * alpha + 0.5)
        end
        return string.format(
          '#%02x%02x%02x',
          mix(ch(hex, 2), ch(other, 2)),
          mix(ch(hex, 4), ch(other, 4)),
          mix(ch(hex, 6), ch(other, 6))
        )
      end

      local cell_hl = function()
        -- band = normal-bg leicht aufgehellt; nvim_get_hl liefert truecolor-int,
        -- kleine ints wären cterm-indizes → dann fallback (sonokai #272822)
        local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = 'Normal', link = false })
        local bg = (ok and type(hl) == 'table' and type(hl.bg) == 'number' and hl.bg > 0x10000)
            and string.format('#%06x', hl.bg)
          or '#272822'
        vim.api.nvim_set_hl(0, 'MoltenCellBand', { bg = hex_blend(bg, '#e2e2e3', 0.08) })
        vim.api.nvim_set_hl(0, 'MoltenCellMarker', { bold = true, fg = '#76cce0' })
      end
      cell_hl()
      vim.api.nvim_create_autocmd('ColorScheme', { callback = cell_hl })

      local place_bands = function(bufnr)
        if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= '' then
          return
        end
        vim.api.nvim_buf_clear_namespace(bufnr, band_ns, 0, -1)
        for i, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
          if l:match '^# %%' then
            vim.api.nvim_buf_set_extmark(bufnr, band_ns, i - 1, 0, { end_row = i, line_hl_group = 'MoltenCellBand' })
          end
        end
      end

      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'python',
        callback = function(e)
          if vim.api.nvim_buf_get_name(e.buf):match '%.ipynb$' then
            vim.cmd 'syn match MoltenCellMarker "^# %%.*"'
          end
        end,
      })

      -- bands pflegen: initial + bei edits (throttled)
      local band_pending = false
      local schedule_bands = function(bufnr)
        if band_pending then
          return
        end
        band_pending = true
        vim.defer_fn(function()
          band_pending = false
          place_bands(bufnr)
        end, 50)
      end
      vim.api.nvim_create_autocmd('BufEnter', {
        pattern = '*.ipynb',
        callback = function(e)
          place_bands(e.buf)
        end,
      })
      vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        pattern = '*.ipynb',
        callback = function(e)
          schedule_bands(e.buf)
        end,
      })

      -- erste ausführung im frischen buffer rast in molten's kernel_check, wenn der
      -- auto-init-kernel noch nicht attached ist → pick-pop, run verloren. hier:
      -- run cappen und pollen bis attached (bzw. direkt ausführen ohne venv)
      local when_ready = function(run)
        if kernel_attached() or detect_venv(vim.fs.dirname(vim.api.nvim_buf_get_name(0))) == nil then
          run()
          return
        end
        local target_buf = vim.api.nvim_get_current_buf()
        local attempts = 0
        local timer = vim.uv.new_timer()
        timer:start(0, 250, vim.schedule_wrap(function()
          if vim.api.nvim_get_current_buf() ~= target_buf then
            timer:stop()
            timer:close()
            return
          end
          if kernel_attached() then
            timer:stop()
            timer:close()
            run()
            return
          end
          attempts = attempts + 1
          if attempts == 4 then
            vim.notify 'molten: kernel startet noch — zelle läuft, sobald er attached ist'
          elseif attempts >= 80 then
            timer:stop()
            timer:close()
            vim.notify('molten: kernel nach 20s nicht attached — :MoltenInfo prüfen', vim.log.levels.WARN)
          end
        end))
      end

      local map = function(lhs, rhs, desc, mode)
        vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc, silent = true })
      end

      -- kernel
      map('<leader>ii', smart_init, 'Init kernel')
      map('<leader>ir', ':MoltenInfo<CR>', 'Molten info')
      map('<leader>irn', ':MoltenRestart!<CR>', 'Nuclear kernel restart')
      -- restart + alles neu: kernel-state reset, zellen laufen via when_ready-queue
      map('<leader>irA', function()
        vim.cmd 'MoltenRestart!'
        when_ready(run_all)
      end, 'Restart kernel + run all cells')
      map('<leader>is<Space>', ':MoltenInterrupt<CR>', 'Interrupt kernel')

      -- execution (iron muscle memory) — alles über when_ready: erste ausführung
      -- wartet auf den auto-init-kernel statt molten's picker zu triggern
      map('<leader>ie', function()
        when_ready(run_cell)
      end, 'Execute cell')
      map('<leader>isb', function()
        when_ready(run_cell)
      end, 'Execute cell')
      map('<leader>ien', function()
        when_ready(run_cell_and_next)
      end, 'Execute cell + jump next')
      map('<leader>isl', function()
        when_ready(function()
          vim.cmd 'MoltenEvaluateLine'
        end)
      end, 'Execute line')
      map('<leader>isc', function()
        when_ready(function()
          vim.cmd 'MoltenEvaluateOperator'
        end)
      end, 'Evaluate operator')
      map('<leader>isc', function()
        when_ready(function()
          vim.cmd 'MoltenEvaluateVisual'
        end)
      end, 'Execute selection', 'v')
      map('<leader>iaa', function()
        when_ready(run_all)
      end, 'Execute all cells')
      map('<leader>iau', function()
        when_ready(run_above)
      end, 'Execute all cells up to current')

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
      map('<leader>in', ':MoltenNext<CR>', 'Next output window')
      map('<leader>ip', ':MoltenPrev<CR>', 'Previous output window')
      map('<leader>imd', ':MoltenDelete<CR>', 'Delete cell output')
      map('<leader>iv', function()
        when_ready(inspect_var)
      end, 'Inspect variable under cursor')

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

      -- reader-view (option C): notebook als gerendertes markdown im centered float.
      -- jupytext CLI konvertiert den disk-stand on-demand (--output -), render-markdown
      -- rendert den scratch-buffer (ft=markdown). read-only, q/<Esc> schließt
      local reader_win = nil

      local close_reader = function()
        if reader_win and vim.api.nvim_win_is_valid(reader_win) then
          vim.api.nvim_win_close(reader_win, true)
        end
        reader_win = nil
      end

      vim.api.nvim_create_user_command('NotebookReader', function()
        if reader_win and vim.api.nvim_win_is_valid(reader_win) then
          close_reader()
          return
        end
        local notebook = vim.api.nvim_buf_get_name(0)
        if not notebook:match '%.ipynb$' then
          vim.notify('reader: cursor auf ein .ipynb setzen', vim.log.levels.WARN)
          return
        end
        if vim.bo.modified then
          vim.notify 'reader: notebook hat ungespeicherte änderungen — :w um sie anzuzeigen'
        end
        local out = vim.fn.system { 'jupytext', '--to', 'md', '--output', '-', notebook }
        if vim.v.shell_error ~= 0 or out == '' then
          vim.notify('reader: jupytext-konvertierung fehlgeschlagen', vim.log.levels.ERROR)
          return
        end
        -- geräuschfilter: yaml-frontmatter, jupytext-region-marker (<!-- #region … -->)
        -- und pycharm-metadata an fence-info-strings sind notebook-intern → raus.
        -- roundtrip-fidilität ist dem reader egal (einbahnstraße)
        local raw = vim.split(out, '\n')
        local cleaned = {}
        local i = 1
        if raw[1] == '---' then
          i = 2
          while i <= #raw and raw[i] ~= '---' do
            i = i + 1
          end
          i = i + 1
        end
        for j = i, #raw do
          local l = raw[j]
          -- find(..., true): plain-text — '-' ist in lua-patterns magic
          if not l:find('<!-- #region', 1, true) and not l:find('<!-- #endregion', 1, true) then
            -- klammern: gsub gibt (string, count) zurück → table.insert würde
            -- beide als (list, pos, value) interpretieren
            table.insert(cleaned, (l:gsub(' pycharm=%b{}', '')))
          end
        end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].bufhidden = 'wipe'
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, cleaned)
        vim.bo[buf].filetype = 'markdown'
        vim.bo[buf].modifiable = false
        local ui = vim.api.nvim_list_uis()[1]
        local w = math.floor((ui and ui.width or 120) * 0.8)
        local h = math.floor((ui and ui.height or 40) * 0.85)
        reader_win = vim.api.nvim_open_win(buf, false, {
          relative = 'editor',
          width = w,
          height = h,
          col = math.floor(((ui and ui.width or 120) - w) / 2),
          row = math.floor(((ui and ui.height or 40) - h) / 2),
          border = 'rounded',
          style = 'minimal',
          title = ' reader: ' .. vim.fs.basename(notebook) .. ' ',
          title_pos = 'center',
        })
        vim.wo[reader_win].wrap = true
        vim.keymap.set('n', 'q', close_reader, { buffer = buf, silent = true })
        vim.keymap.set('n', '<Esc>', close_reader, { buffer = buf, silent = true })
        -- notebook-buffer geht zu → reader-float mit zu
        vim.api.nvim_create_autocmd('BufWipeout', {
          buffer = vim.api.nvim_get_current_buf(),
          once = true,
          callback = close_reader,
        })
      end, {})

      map('<leader>im', ':NotebookReader<CR>', 'Toggle notebook reader view')

      -- beim ipynb-öffnen: passenden kernel init + outputs importieren
      local imb = function(e)
        vim.schedule(function()
          -- molten-remote-funktionen existieren erst nach :UpdateRemotePlugins + restart;
          -- exists('*fn') ist bei remote-fns 0 bis zum ersten call → command-check nutzen
          if vim.fn.exists ':MoltenInit' ~= 2 then
            vim.notify 'Molten: remote plugin not registered yet — restart nvim after :Lazy sync'
            return
          end
          local kernels = vim.fn.MoltenAvailableKernels()
          local kernel_name = nil
          local ok, meta = pcall(function()
            return vim.json.decode(io.open(e.file, 'r'):read 'a').metadata.kernelspec.name
          end)
          if ok and meta and vim.tbl_contains(kernels, meta) then
            kernel_name = meta
          else
            -- kein passender kernelspec → venv finden + spec registrieren (idempotent)
            local venv = detect_venv(vim.fs.dirname(e.file))
            if venv then
              if has_ipykernel(venv) then
                kernel_name = ensure_spec(venv)
              else
                vim.notify('molten: no ipykernel in ' .. venv .. ' — run: uv pip install ipykernel', vim.log.levels.WARN)
              end
            end
          end
          if kernel_name then
            pcall(vim.cmd, { cmd = 'MoltenInit', args = { kernel_name } })
          end
          pcall(vim.cmd, 'MoltenImportOutput')
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

      -- beim speichern: outputs ins .ipynb zurückschreiben (nur mit attached kernel)
      vim.api.nvim_create_autocmd('BufWritePost', {
        pattern = '*.ipynb',
        callback = function()
          if vim.fn.exists ':MoltenExportOutput' ~= 2 then
            return
          end
          if kernel_attached() then
            pcall(vim.cmd, 'MoltenExportOutput!')
          end
        end,
      })

      -- outputs rendern jetzt einheitlich im float-window (virt_text_output=false
      -- in init) → die alten per-buffer virt-text-option-switches sind überflüssig

      -- ipython-magics (%foo, !cmd) sind kein valides python → pyright meldet auf jeder
      -- magic-zeile syntax-errors. kernel versteht magics trotzdem → diagnostics in
      -- notebook-buffern live filtern: zeilen die mit %/! beginnen raus, real errors bleiben.
      -- message-agnostisch (pyright-formulierungen variieren), selbst-heilend bei republish
      local is_magic_line = function(bufnr, lnum)
        local line = vim.api.nvim_buf_get_lines(bufnr, lnum, lnum + 1, false)[1] or ''
        return line:find('^%%') ~= nil or line:find('^!') ~= nil
      end

      -- regeln die im notebook-kontext per konstruktion false-positive sind:
      -- E402 (import nicht am anfang) — ruff sieht den buffer als flaches modul,
      -- aber jede zelle ist ein eigener scope, imports mitten drin sind normal
      local noise_codes = { E402 = true }

      local filter_diagnostics = function(bufnr)
        local keep = {}
        local dirty = false
        for _, d in ipairs(vim.diagnostic.get(bufnr)) do
          if is_magic_line(bufnr, d.lnum) or (d.code ~= nil and noise_codes[d.code] == true) then
            dirty = true
          else
            -- nur standard-felder zurückgeben (get() hängt namespace/_extmark_id an)
            local clean = {
              lnum = d.lnum,
              col = d.col,
              end_lnum = d.end_lnum,
              end_col = d.end_col,
              severity = d.severity,
              message = d.message,
              source = d.source,
              code = d.code,
              user_data = d.user_data,
            }
            keep[d.namespace] = keep[d.namespace] or {}
            table.insert(keep[d.namespace], clean)
          end
        end
        if not dirty then
          return
        end
        for ns, diags in pairs(keep) do
          vim.diagnostic.set(ns, bufnr, diags)
        end
      end

      -- re-entrancy-guard: unser eigenes vim.diagnostic.set feuert DiagnosticChanged
      -- sync-nested → ohne guard läuft der handler in sich selbst (E218 nesting too
      -- deep, live-LSP publishs machen's reproduzierbar). ein publish = genau ein
      -- filter-pass; der nächste echte publish filtert erneut
      local filtering = false
      local filter_augroup = vim.api.nvim_create_augroup('molten_diag_filter', { clear = true })
      vim.api.nvim_create_autocmd('DiagnosticChanged', {
        group = filter_augroup,
        pattern = '*.ipynb',
        callback = function(e)
          if filtering then
            return
          end
          filtering = true
          local ok, err = pcall(filter_diagnostics, e.buf)
          filtering = false
          if not ok then
            vim.notify('molten: diagnostic filter failed: ' .. tostring(err), vim.log.levels.ERROR)
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
