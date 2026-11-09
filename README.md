# Zigine

A small graphics engine written in Zig using OpenGL.

## Running

First install zig 0.17.0 from https://ziglang.org/download/#release-0.17.0.

If you have nix package manager you can run `nix develop` to enter the nix flake environment for easy setup.

Then from the project root:

```bash
zig build run
```

Controls
- 1,2,3: Switch between scenes
- WASD: move camera around
- Arrow keys: move cornell light around
- Space: move camera up
- Ctrl: move down
- Mouse: look around
- Esc: close the window

## Note

Credits to the assets are found in `assets/CREDITS.md`
AI is used for better understanding the problem
