# Tool Bundles
#
# Pre-defined collections of commonly useful development tools.
# Include them via agentbox.toml: [bundles] include = ["baseline"]
#
# These are curated sets of standalone CLI tools that work well together.

{
  # baseline: Modern terminal essentials (28 tools)
  # A curated set of standalone CLI tools (no Python/Perl/Ruby runtimes)
  baseline = [
    # Core replacements
    "ripgrep" "fd" "bat" "eza" "sd" "dust" "duf" "bottom" "difftastic"
    # Navigation & search
    "zoxide" "fzf" "broot" "tree"
    # Git
    "delta" "lazygit"
    # Data processing
    "jq" "yq-go" "csvtk" "htmlq" "miller"
    # Shell enhancement
    "atuin" "direnv" "just"
    # Utilities
    "tealdeer" "curlie" "glow" "entr" "pv"
  ];

  # complete: Comprehensive dev environment (61 tools)
  # Everything in baseline plus additional tools for a fully-equipped shell
  complete = [
    # Core replacements
    "ripgrep" "fd" "bat" "eza" "sd" "dust" "duf" "bottom" "difftastic"
    # Navigation & search
    "zoxide" "fzf" "broot" "tree"
    # Git
    "delta" "lazygit"
    # Data processing
    "jq" "yq-go" "csvtk" "htmlq" "miller"
    # Shell enhancement
    "atuin" "direnv" "just"
    # Utilities
    "tealdeer" "curlie" "glow" "entr" "pv"
    # Additional core replacements
    "procs" "choose"
    # Git & GitHub
    "gh" "git-extras" "tig"
    # Data processing
    "fx"
    # Shell enhancement
    "shellcheck" "starship" "gum"
    # File operations
    "rsync" "trash-cli" "watchexec" "renameutils"
    # Networking
    "curl" "wget" "httpie"
    # Archives
    "unzip" "p7zip" "zstd"
    # System utilities
    "tmux" "watch" "less" "file" "lsof" "moreutils"
    # Development utilities
    "hyperfine" "tokei" "navi"
    # Terminal recording & screenshots
    "vhs" "freeze"
    # Clipboard
    "xclip" "wl-clipboard"
    # Logs
    "lnav"
  ];
}
