# Zigine

A small graphics engine written in Zig using OpenGL.

## Running

First install zig 0.16.0 from https://ziglang.org/download/#release-0.16.0.

If you have nix package manager you can run `nix develop` to enter the nix flake environment for easy setup.

Then from the project root:

```bash
zig build run
```

Controls
- W: move forward
- S: move backward
- A: move left
- D: move right
- Space: move up
- Ctrl: move down
- Mouse: look around
- Esc: close the window
