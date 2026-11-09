const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("c.zig");
const Window = @import("Window.zig");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;
const Input = @This();

mouse_x: f64 = 0,
mouse_y: f64 = 0,

mouse_dx: f64 = 0, // mouse delta x
mouse_dy: f64 = 0, // mouse delta y

first_mouse: bool = true,

keys_down: [glfw.GLFW_KEY_LAST + 1]bool = @splat(false),
keys_pressed: [glfw.GLFW_KEY_LAST + 1]bool = @splat(false),
window: *Window,

pub fn init(self: *Input, window: *Window) void {
    self.* = .{ .window = window };
    glfw.glfwSetWindowUserPointer(window.window, self);
    _ = glfw.glfwSetKeyCallback(window.window, keyCallback);
    _ = glfw.glfwSetCursorPosCallback(window.window, cursorCallback);
}

pub fn captureCursor(self: *Input, enable: bool) void {
    if (enable == true) {
        self.first_mouse = true;
        glfw.glfwSetInputMode(
            self.window.window,
            glfw.GLFW_CURSOR,
            glfw.GLFW_CURSOR_DISABLED,
        );
    } else {
        glfw.glfwSetInputMode(
            self.window.window,
            glfw.GLFW_CURSOR,
            glfw.GLFW_CURSOR_NORMAL,
        );
    }
}

pub fn endFrame(self: *Input) void {
    self.mouse_dx = 0;
    self.mouse_dy = 0;
    @memset(&self.keys_pressed, false);
}

pub fn wasPressed(self: *const Input, key: c_int) bool {
    return self.keys_pressed[@intCast(key)];
}

fn cursorCallback(
    window: ?*glfw.GLFWwindow,
    x: f64,
    y: f64,
) callconv(.c) void {
    const ptr = glfw.glfwGetWindowUserPointer(window) orelse return;
    const self: *Input = @ptrCast(@alignCast(ptr));

    if (self.first_mouse) {
        self.mouse_x = x;
        self.mouse_y = y;
        self.first_mouse = false;
        return;
    }

    self.mouse_dx += x - self.mouse_x;
    self.mouse_dy += y - self.mouse_y;

    self.mouse_x = x;
    self.mouse_y = y;
}

fn keyCallback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mode: c_int,
) callconv(.c) void {
    _ = scancode;
    _ = mode;

    const ptr = glfw.glfwGetWindowUserPointer(window) orelse return;
    const self: *Input = @ptrCast(@alignCast(ptr));

    if (key >= 0 and key <= glfw.GLFW_KEY_LAST) {
        if (action == glfw.GLFW_PRESS) {
            self.keys_down[@intCast(key)] = true;
            self.keys_pressed[@intCast(key)] = true;
        } else if (action == glfw.GLFW_RELEASE) {
            self.keys_down[@intCast(key)] = false;
        }
    }

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        self.window.close();
    }
}
