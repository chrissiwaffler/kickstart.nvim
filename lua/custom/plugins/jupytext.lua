-- .ipynb als plaintext öffnen/speichern via jupytext-CLI (nix: extraPackages = [ jupytext ])
-- default-style "hydrogen" = `# %%`-marker → native python-buffer (LSP/conform/ruff arbeiten normal)
return {
  'GCBallesteros/jupytext.nvim',
  lazy = false, -- muss vor BufReadPre von .ipynb geladen sein
  config = true,
}
