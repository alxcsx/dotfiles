#!/bin/sh
# Automatically point ~/.local/share/mise/current-elixir to the active Elixir version in use
if command -v mise >/dev/null 2>&1; then
  elixir_dir=$(mise where elixir 2>/dev/null)
  if [ -n "$elixir_dir" ] && [ -d "$elixir_dir" ]; then
    ln -sfn "$elixir_dir" "$HOME/.local/share/mise/current-elixir"
  fi
fi
