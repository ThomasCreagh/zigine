const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("c.zig");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;
const Window = @This();

const Error = error{
    GlfwInitFailed,
    GladInitFailed,
    FailedToOpenWindow,
};

window: *glfw.GLFWwindow,

pub fn init() !Window {
    _ = glfw.glfwSetErrorCallback(errorCallback);
    if (glfw.glfwInit() == 0) return Error.GlfwInitFailed;
    errdefer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GL_TRUE); // For MacOS
    glfw.glfwWindowHint(
        glfw.GLFW_OPENGL_PROFILE,
        glfw.GLFW_OPENGL_CORE_PROFILE,
    );

    const window = glfw.glfwCreateWindow(
        1920,
        1080,
        "zingine",
        null,
        null,
    ) orelse return Error.FailedToOpenWindow;
    errdefer glfw.glfwDestroyWindow(window);

    glfw.glfwMakeContextCurrent(window);

    _ = glfw.glfwSetFramebufferSizeCallback(
        window,
        framebufferSizeCallback,
    );

    if (gl.gladLoadGLLoader(
        @ptrCast(&glfw.glfwGetProcAddress),
    ) == 0) {
        return Error.GladInitFailed;
    }

    // depth teseting
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LESS);

    return .{ .window = window };
}

pub fn poll(self: *Window) void {
    _ = self;
    glfw.glfwPollEvents();
}

pub fn swapBuffers(self: *Window) void {
    glfw.glfwSwapBuffers(self.window);
}

pub fn clear(self: *Window) void {
    _ = self;
    gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
}

pub fn shouldClose(self: *Window) bool {
    return glfw.glfwWindowShouldClose(self.window) != 0;
}

pub fn vsync(self: *Window, enable: bool) void {
    _ = self;
    if (enable == true) {
        glfw.glfwSwapInterval(1);
    } else {
        glfw.glfwSwapInterval(0);
    }
}

pub fn close(self: *Window) void {
    glfw.glfwSetWindowShouldClose(self.window, gl.GL_TRUE);
}

pub fn deinit(self: *Window) void {
    glfw.glfwDestroyWindow(self.window);
    glfw.glfwTerminate();
}

fn framebufferSizeCallback(
    window: ?*glfw.GLFWwindow,
    width: c_int,
    height: c_int,
) callconv(.c) void {
    _ = window;
    gl.glViewport(0, 0, width, height);
}

fn errorCallback(
    err: c_int,
    description: [*c]const u8,
) callconv(.c) void {
    std.debug.print("GLFW Error {}: {s}\n", .{ err, description });
}
