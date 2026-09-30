const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("c.zig");

const Triangle = @import("graphics/gl_objects/triangle.zig").Triangle;
const Axis = @import("graphics/gl_objects/axis.zig").Axis;
const Cube = @import("graphics/gl_objects/cube.zig").Cube;
const Building = @import("graphics/gl_objects/building.zig").Building;
const Skybox = @import("graphics/gl_objects/skybox.zig").Skybox;

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

var viewPolar: f32 = std.math.pi / 4.0; // start at 45 degrees
var viewAzimuth: f32 = std.math.pi / 4.0;
var viewDistance: f32 = 17.32;
var eye_center: zalg.Vec3 = zalg.Vec3.new(10, 10, 10);

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

    glfw.glfwSetInputMode(window, glfw.GLFW_STICKY_KEYS, glfw.GL_TRUE);
    _ = glfw.glfwSetKeyCallback(window, keyCallback);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1); // vsync

    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        std.debug.print("Failed to load gl loader\n", .{});
        return;
    }

    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LESS);
    gl.glEnable(gl.GL_CULL_FACE);

    var fb_w: c_int = 0;
    var fb_h: c_int = 0;
    glfw.glfwGetFramebufferSize(window, &fb_w, &fb_h);
    gl.glViewport(0, 0, fb_w, fb_h);
    const aspect = @as(f32, @floatFromInt(fb_w)) / @as(f32, @floatFromInt(fb_h));

    const projection = zalg.Mat4.perspective(45.0, aspect, 0.1, 100.0);

    gl.glClearColor(0.3, 0.4, 0.5, 0.0);

    var triangle: Triangle = .{};
    try triangle.initialize(io, allocator);
    defer triangle.cleanup();

    var axis: Axis = .{};
    try axis.initialize(io, allocator);
    defer axis.cleanup();

    var skybox: Skybox = .{};
    try skybox.initialize(io, allocator, "assets/textures/sky.png");
    defer skybox.cleanup();

    // var cube: Cube = .{};
    // try cube.initialize(io, allocator);
    // defer cube.cleanup();

    var building: Building = .{};
    try building.initialize(
        io,
        allocator,
        zalg.Vec3{ .data = .{ 0, 0, 0 } },
        zalg.Vec3{ .data = .{ 1, 2, 1 } },
        "assets/textures/facade0.jpg",
    );
    defer building.cleanup();

    var z_offset: f32 = -1.0;
    var direction: f32 = -1.0;

    while (glfw.glfwWindowShouldClose(window) == 0) {
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        updateCamera();

        const view = zalg.Mat4.lookAt(
            eye_center,
            zalg.Vec3.new(0, 0, 0), // look at origin
            zalg.Vec3.new(0, 1, 0), // up vector
        );
        const view_projection = zalg.Mat4.mul(projection, view);

        if (z_offset <= -2.0 and direction == -1.0) direction = 1.0;
        if (z_offset >= 2.0 and direction == 1.0) direction = -1.0;
        z_offset += 0.1 * direction;

        triangle.position = zalg.Vec3.new(0, 0, z_offset);

        skybox.render(view, projection);

        triangle.render(view_projection);
        axis.render(view_projection);
        // cube.render(view_projection);
        building.render(view_projection);

        glfw.glfwPollEvents();
        glfw.glfwSwapBuffers(window);
    }
}

var keys_down: [glfw.GLFW_KEY_LAST + 1]bool = [_]bool{false} ** (glfw.GLFW_KEY_LAST + 1);

fn keyCallback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mode: c_int,
) callconv(.c) void {
    _ = scancode;
    _ = mode;

    if (key >= 0 and key <= glfw.GLFW_KEY_LAST) {
        if (action == glfw.GLFW_PRESS) {
            keys_down[@intCast(key)] = true;
        } else if (action == glfw.GLFW_RELEASE) {
            keys_down[@intCast(key)] = false;
        }
    }

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, gl.GL_TRUE);
    }
}

const polar_min: f32 = 0.01;
const polar_max: f32 = std.math.pi - 0.01;

const view_distance_min: f32 = 1.0;
const view_distance_max: f32 = 100.0;
const view_distance_speed: f32 = 0.2;

fn updateCamera() void {
    var camera_changed = false;

    if (keys_down[glfw.GLFW_KEY_UP] or keys_down[glfw.GLFW_KEY_W]) {
        viewPolar -= 0.05;
        camera_changed = true;
    }

    if (keys_down[glfw.GLFW_KEY_DOWN] or keys_down[glfw.GLFW_KEY_S]) {
        viewPolar += 0.05;
        camera_changed = true;
    }

    if (keys_down[glfw.GLFW_KEY_LEFT] or keys_down[glfw.GLFW_KEY_A]) {
        viewAzimuth -= 0.05;
        camera_changed = true;
    }

    if (keys_down[glfw.GLFW_KEY_RIGHT] or keys_down[glfw.GLFW_KEY_D]) {
        viewAzimuth += 0.05;
        camera_changed = true;
    }

    if (keys_down[glfw.GLFW_KEY_Z]) {
        viewDistance -= view_distance_speed;
        camera_changed = true;
    }

    if (keys_down[glfw.GLFW_KEY_X]) {
        viewDistance += view_distance_speed;
        camera_changed = true;
    }

    viewPolar = std.math.clamp(viewPolar, polar_min, polar_max);
    viewDistance = std.math.clamp(
        viewDistance,
        view_distance_min,
        view_distance_max,
    );

    if (camera_changed) {
        eye_center = zalg.Vec3.new(
            viewDistance * @sin(viewPolar) * @cos(viewAzimuth),
            viewDistance * @cos(viewPolar),
            viewDistance * @sin(viewPolar) * @sin(viewAzimuth),
        );
    }
}

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error {}: {s}\n", .{ err, description });
}
