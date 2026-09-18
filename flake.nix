{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # zig
        zig
        zls

        # GL
        mesa
        mesa-gl-headers
        mesa-demos
        libGL.dev
        libGLU

        # X11
        libX11
        libXrandr
        libXinerama
        libXcursor
        libXi

        # Wayland
        wayland
        libxkbcommon
      ];
      shellHook = ''
        export ZIG_GLOBAL_CACHE_DIR="$HOME/.cache/zig"
        mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
        export GL_HEADERS="${pkgs.libGL.dev}"

        export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
          pkgs.wayland
          pkgs.libxkbcommon
          pkgs.libGL
          pkgs.libX11
          pkgs.libXrandr
          pkgs.libXinerama
          pkgs.libXcursor
          pkgs.libXi
        ]}:$LD_LIBRARY_PATH"
      '';
    };
  };
}

