# Tool Bundles
#
# Pre-defined collections of commonly useful development tools.
# Include them via agentbox.toml: [bundles] include = ["baseline"]
#
# These are curated sets of standalone CLI tools that work well together.

{
  # distrobox: Dependencies required for distrobox container entry
  # These are automatically included in OCI images built with mkProjectImage.
  # Distrobox's init script checks for these tools and tries to install them
  # via package manager if missing. By pre-installing them, we skip that step.
  #
  # Note: Some tools map to package names differently:
  #   - shadow: useradd, passwd, chpasswd
  #   - util-linux: mount, umount, findmnt, script
  #   - procps: ps
  #   - iputils: ping
  #   - diffutils: diff
  #   - findutils: find
  distrobox = [
    # Compression & archives
    "bc" "bzip2" "pigz" "zip" "unzip" "gzip" "gnutar"
    # User management (shadow package)
    "shadow"
    # Process & system utilities
    "procps" "lsof" "util-linux" "time" "hostname" "glibc.bin"
    # Filesystem
    "diffutils" "findutils"
    # Security & crypto
    "gnupg" "pinentry-curses" "sudo"
    # Network
    "iputils"
    # X11 (for GUI forwarding)
    "xorg.xauth"
    # Documentation
    "man-db"
    # Core tools (some overlap with substrate, but explicit for distrobox)
    "coreutils" "bash" "less" "tree" "curl" "wget" "openssh" "rsync" "gnugrep" "gnused"
  ];

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
