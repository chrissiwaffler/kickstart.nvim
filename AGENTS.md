# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-30
**Commit:** 472edff
**Branch:** master

## OVERVIEW

Personal Neovim config forked from kickstart.nvim. Lua-based, uses lazy.nvim for plugin management. Monolithic init.lua (1584 lines) with modular custom plugins in `lua/custom/plugins/`.

## STRUCTURE

```
kickstart.nvim/
├── init.lua                          # Everything: options, keymaps, plugins, LSP, formatters
├── lua/
│   ├── kickstart/
│   │   ├── health.lua                # :checkhealth module
│   │   └── plugins/                  # Optional kickstart plugin modules (commented out in init.lua)
│   │       ├── debug.lua             # DAP + dap-ui (Go-focused)
│   │       ├── gitsigns.lua          # Gitsigns with recommended keymaps
│   │       ├── autopairs.lua         # nvim-autopairs
│   │       ├── indent_line.lua       # indent-blankline (but ibl configured inline in init.lua)
│   │       ├── lint.lua              # nvim-lint
│   │       └── neo-tree.lua          # neo-tree file explorer (but nvim-tree used instead)
│   └── custom/
│       └── plugins/                  # User's custom plugins (auto-imported via lazy)
│           ├── init.lua              # Empty placeholder
│           ├── alpha.lua             # Dashboard with terminal image
│           ├── avante.lua            # AI coding assistant (Claude)
│           ├── iron-kitty.lua        # Iron.nvim REPL with Jupyter-style cells
│           └── outline.lua           # Aerial symbol outline
├── colors/Monokai-Charcoal.vim       # Custom colorscheme
├── start_image/                      # Dashboard images (blue-eyes binary)
├── .stylua.toml                      # StyLua config (column_width=160, spaces, 2-indent)
└── .github/workflows/stylua.yml      # CI: StyLua format check on PRs
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add a new plugin | `lua/custom/plugins/*.lua` | Each file returns lazy.nvim spec table. Auto-imported. |
| Change vim options | `init.lua` lines 96-196 | Number, clipboard, tabs, scrolloff, etc. |
| Change keymaps | `init.lua` lines 197-245 (general), 593-625 (telescope), 695-828 (LSP) | All use `desc` for which-key |
| Configure LSP servers | `init.lua` lines 847-898 | `servers` table → mason auto-installs |
| Configure formatters | `init.lua` lines 984-1038 | conform.nvim `formatters_by_ft` table |
| Add Mason tools | `init.lua` lines 911-925 | `ensure_installed` list |
| Change colorscheme | `init.lua` lines 1187-1196 | Currently: sonokai (sublime style). Also: monokai-nightasty installed |
| Configure VimTeX | `init.lua` lines 1338-1432 | LaTeX compile, viewer, conceal, keymaps under `<leader>l` |
| Configure REPL/Cells | `lua/custom/plugins/iron-kitty.lua` | Iron.nvim with `# %%` cell support for Python |
| Configure AI assistant | `lua/custom/plugins/avante.lua` | Avante.nvim with Claude 3.7 Sonnet |
| Change dashboard | `lua/custom/plugins/alpha.lua` | Alpha with terminal image + custom buttons |
| Symbol outline | `lua/custom/plugins/outline.lua` | Aerial.nvim under `<leader>o` |
| Folding | `init.lua` lines 1433-1475 | nvim-ufo, treesitter+indent, `<leader>zf` for Python fold |
| File explorer | `init.lua` lines 1238-1254 + 1522-1538 | nvim-tree (not neo-tree). `<leader>tf` to toggle |
| Buffer line | `init.lua` lines 373-456 | barbar.nvim (bufferline disabled). `<leader>p/n/x/P` |
| Debugging | `lua/kickstart/plugins/debug.lua` | Must uncomment in init.lua to enable. Go-focused. |

## KEYMAP PREFIXES

| Prefix | Mode | Group | Location |
|--------|------|-------|----------|
| `<space>s` | n | Search (Telescope) | init.lua |
| `<space>c` | n | Code (LSP actions) | init.lua |
| `<space>r` | n | Rename/References | init.lua |
| `<space>d` | n | Document symbols | init.lua |
| `<space>w` | n | Workspace | init.lua |
| `<space>t` | n | Toggle (tree, diffview, folds) | init.lua |
| `<space>h` | n/v | Git hunk | init.lua |
| `<space>l` | n | LaTeX (VimTeX, buffer-local) | init.lua |
| `<space>o` | n | Outline (Aerial) | outline.lua |
| `<space>i` | n | Iron REPL/interactive | iron-kitty.lua |
| `<space>f` | n | Format buffer | init.lua (conform) |
| `<space>b` | n | Debug breakpoint (if debug enabled) | debug.lua |
| `gd/gr/gI/gD` | n | LSP navigation | init.lua |
| `gs` | n | Go to definition in split | init.lua |
| `[q/]q` | n | Quickfix nav | init.lua |
| `]f/[f` | n | Next/prev function (treesitter) | init.lua |

## CONVENTIONS

- **Plugin specs**: Each file in `lua/custom/plugins/` returns a single lazy.nvim spec table (or array of specs)
- **Plugin import**: `{ import = 'custom.plugins' }` in `lazy.setup()` — all files auto-loaded
- **Keymaps**: Always use `desc` option for which-key discoverability
- **Formatting**: StyLua enforced (CI + local). Settings: column_width=160, spaces, 2-indent, single quotes, no call parens
- **Comments**: Mixed English/German
- **Clipboard**: OSC 52 as default. WSL override for win32yank. `unnamedplus` sync.
- **Delete**: `d/c/x` mapped to black-hole register (`"_d`) to preserve clipboard
- **Tabs**: 2-space indent, expandtab=true
- **Leader**: `<space>` (set before plugin load)

## ANTI-PATTERNS (THIS PROJECT)

- **NEVER** use neo-tree — nvim-tree is the chosen file explorer (bufferline also disabled in favor of barbar)
- **NEVER** enable treesitter for tex/latex files — VimTeX handles syntax (autocmd disables TS)
- **NEVER** add plugins directly in init.lua's `lazy.setup()` table — put them in `lua/custom/plugins/*.lua`
- **NEVER** use `jedi_language_server` — explicitly skipped in mason-lspconfig handler (pyright is the Python LSP)
- **nil_ls** (Nix LSP) must be installed manually outside Mason — Mason install is broken for it

## COMMANDS

```bash
# Format check (what CI runs)
npx stylua --check .

# Open plugin manager
# :Lazy          — view/manage plugins
# :Mason         — view/manage LSP servers/tools
# :checkhealth   — verify system setup
```

## NOTES

- `init.lua` is deliberately monolithic (kickstart philosophy). The `lua/custom/plugins/` dir is the modular escape hatch.
- Kickstart's optional plugins in `lua/kickstart/plugins/` are NOT loaded by default — they must be uncommented in init.lua's lazy.setup (lines 1487-1492).
- Isabelle/HOL LSP requires manual install at `/Users/chrissi/isabelle_tooling/isabelle-language-server/`.
- `start_image/blue-eyes` is a compiled binary for the alpha dashboard image — config-specific, not portable.
- LSP `gd` is overridden with custom function that jumps directly (no Telescope picker) for speed. `gs` opens in split via Telescope.
- `K` (hover) is overridden by nvim-ufo to peek folds first, falls back to LSP hover if no fold under cursor.
- Python formatting chain: ruff_fix → ruff_format → isort → black (conform.nvim runs sequentially).
- C/C++ formatting via clang-format. Compile commands expected in `build/` dir.
