{ pkgs, config, ... }:

{
  packages = [
    pkgs.android-tools
    pkgs.cloudflared
    pkgs.git
    pkgs.jdk17
    pkgs.mise
    pkgs.ripgrep
    pkgs.sqlite
  ];

  env = {
    GRADLE_USER_HOME = "${config.git.root}/android/.gradle";
    POTDROID_API_BASE_URL = "http://localhost:3000";
  };

  enterShell = ''
    export ANDROID_HOME="''${ANDROID_HOME:-$HOME/Library/Android/sdk}"
    export ANDROID_SDK_ROOT="''${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
    mkdir -p "$GRADLE_USER_HOME"
    echo "PotDroid dev environment"
    echo "  Rails:   scripts/dev"
    echo "  Tunnel:  scripts/tunnel"
    echo "  Tests:   scripts/test"
  '';

  processes = {
    rails.exec = "scripts/dev";
  };

  scripts = {
    test.exec = "scripts/test";
    rails.exec = "scripts/dev";
    tunnel.exec = "scripts/tunnel";
    console.exec = "rails/bin/rails console";
  };
}
