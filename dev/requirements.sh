#!/bin/bash
# name:		dev.requirements.sh
# desc:		requirements for dev module
# author:	Alex Candido <github:alxcsx>
set -e
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../.utils/packages.sh"

# ----- Custom Installers -----
custom_install "mise" "all" "curl https://mise.run | sh"

override_pkg "openssl" "ubuntu" "libssl-dev"
override_pkg "openssl" "debian" "libssl-dev"
override_pkg "pkgconf" "ubuntu" "pkg-config"
override_pkg "pkgconf" "debian" "pkg-config"

# --- Tools ---
require "git"
require "mise"
require "podman"
require "podman-compose"
require "direnv"

require "openssl"
require "pkgconf"

# --- HTTP client
require "xh"

# --- Language Tools
require "bash-language-server"

# --- Erlang build dependencies (wxwidgets, etc.) ---
override_pkg "wxwidgets" "ubuntu" "libwxgtk3.0-gtk3-dev"
override_pkg "wxwidgets" "debian" "libwxgtk3.0-gtk3-dev"
override_pkg "libffi" "ubuntu" "libffi-dev"
override_pkg "libffi" "debian" "libffi-dev"
override_pkg "unixodbc" "ubuntu" "unixodbc-dev"
override_pkg "unixodbc" "debian" "unixodbc-dev"

require "wxwidgets"
require "libffi"
require "unixodbc"

# --- OS-Specific Elixir/Phoenix Watcher
if [[ "$OS" == "linux" ]]; then
    require "inotify-tools"
fi
