const std = @import("std");
const zalg = @import("zalgebra");
const glfw = c.glfw;
const gl = c.glad;

const c = @import("c.zig");
const shader_loader = @import("shader_loader.zig");
const Triangle = @import("gl_objects/triangle.zig").Triangle;

const Io = std.Io;

pub fn run(io: Io, allocator: std.mem.Allocator) !void {
    _ = glfw.glfwSetErrorCallback(errorCallback);
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed glfw init\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GL_TRUE); // For MacOS
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1920, 1080, "zingine", null, null);
    if (window == null) {
        std.debug.print("Failed window open\n", .{});
        return;
    }
    defer glfw.glfwDestroyWindow(window);

    // Ensure we can capture the escape key being pressed below
    glfw.glfwSetInputMode(window, glfw.GLFW_STICKY_KEYS, glfw.GL_TRUE);
    _ = glfw.glfwSetKeyCallback(window, keyCallback);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1); // vsync

    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        std.debug.print("Failed to load gl loader\n", .{});
        return;
    }

    const projection = zalg.Mat4.perspective(45.0, 4.0 / 3.0, 0.1, 100.0);
    const view = zalg.Mat4.lookAt(
        zalg.Vec3.new(0, 0, 3), // pos
        zalg.Vec3.new(0, 0, 0), // look at origin
        zalg.Vec3.new(0, 1, 0), // up vector
    );
    const model = zalg.Mat4.fromTranslate(zalg.Vec3.new(0, 0, 0));
    const mvp = zalg.Mat4.mul(projection, zalg.Mat4.mul(view, model));

    gl.glClearColor(0.1, 0.1, 0.1, 1.0);

    var triangle: Triangle = .{};
    try triangle.initialize(io, allocator);
    defer triangle.cleanup();

    while (glfw.glfwWindowShouldClose(window) == 0) {
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
        triangle.render(mvp);
        glfw.glfwPollEvents();
        glfw.glfwSwapBuffers(window);
    }
}

// Is called whenever a key is pressed/released via GLFW
fn keyCallback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mode: c_int,
) callconv(.c) void {
    _ = scancode;
    _ = mode;

    if (key == glfw.GLFW_KEY_SPACE and action == glfw.GLFW_PRESS) {
        std.debug.print("space pressed\n", .{});
    }

    if (key == glfw.GLFW_KEY_A and action == glfw.GLFW_PRESS) {
        std.debug.print("(A) key pressed\n", .{});
    }

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, gl.GL_TRUE);
    }
}

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error {}: {s}\n", .{ err, description });
}
