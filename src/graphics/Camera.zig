const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../c.zig");
const Transform = @import("Transform.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

const clamp = std.math.clamp;
const Io = std.Io;
const gl = c.glad;
const glfw = c.glfw;

const Camera = @This();

const max_pitch = std.math.pi / 2.0 - 0.01;
const mouse_sensitivity: f32 = 0.001;
const position_speed: f32 = 5;

window: *Window,
input: *Input,

transform: Transform = .{},
fov: f32 = 45.0,
near_plane: f32 = 0.1,
far_plane: f32 = 100.0,

fb_w: c_int = 0,
fb_h: c_int = 0,

pub fn init(self: *Camera) !void {
    glfw.glfwGetFramebufferSize(
        self.window.*.window,
        &self.fb_w,
        &self.fb_h,
    ); // get window size
    gl.glViewport(0, 0, self.fb_w, self.fb_h);
    self.transform.position = zalg.Vec3.new(5, 5, 5);
    self.transform.rotation = zalg.Vec3.new(-0.785, -0.785, 0);
}

pub fn update(self: *Camera, dt: f32) void {

    // mouse
    self.transform.rotation.data[0] -=
        @as(f32, @floatCast(self.input.mouse_dy)) * mouse_sensitivity;

    self.transform.rotation.data[1] +=
        @as(f32, @floatCast(self.input.mouse_dx)) * mouse_sensitivity;

    self.transform.rotation.data[0] = clamp(
        self.transform.rotation.data[0],
        -max_pitch,
        max_pitch,
    );

    // keys
    const keys_down = self.input.keys_down;

    const yaw = self.transform.rotation.data[1];

    const forward = zalg.Vec3.new(
        @sin(yaw),
        0,
        -@cos(yaw),
    );

    const right = zalg.Vec3.new(
        @cos(yaw),
        0,
        @sin(yaw),
    );

    const amount = position_speed * dt;

    if (keys_down[glfw.GLFW_KEY_W]) {
        self.transform.position =
            self.transform.position.add(forward.scale(amount));
    }
    if (keys_down[glfw.GLFW_KEY_S]) {
        self.transform.position =
            self.transform.position.sub(forward.scale(amount));
    }
    if (keys_down[glfw.GLFW_KEY_A]) {
        self.transform.position =
            self.transform.position.sub(right.scale(amount));
    }
    if (keys_down[glfw.GLFW_KEY_D]) {
        self.transform.position =
            self.transform.position.add(right.scale(amount));
    }

    if (keys_down[glfw.GLFW_KEY_SPACE]) {
        self.transform.position.data[1] += amount;
    }
    if (keys_down[glfw.GLFW_KEY_LEFT_CONTROL]) {
        self.transform.position.data[1] -= amount;
    }
}

pub fn viewMatrix(self: *const Camera) zalg.Mat4 {
    const eye = self.transform.position;
    const target = eye.add(self.cameraForward());

    return zalg.Mat4.lookAt(
        eye,
        target,
        zalg.Vec3.new(0, 1, 0),
    );
}

pub fn projectionMatrix(self: *Camera) zalg.Mat4 {
    self.fb_w = 0;
    self.fb_h = 0;

    glfw.glfwGetFramebufferSize(
        self.window.window,
        &self.fb_w,
        &self.fb_h,
    );

    if (self.fb_h == 0) return zalg.Mat4.identity();

    const aspect =
        @as(f32, @floatFromInt(self.fb_w)) /
        @as(f32, @floatFromInt(self.fb_h));

    return zalg.Mat4.perspective(
        45.0,
        aspect,
        0.1,
        100.0,
    );
}

fn cameraForward(self: *const Camera) zalg.Vec3 {
    const pitch = self.transform.rotation.data[0];
    const yaw = self.transform.rotation.data[1];

    return zalg.Vec3.new(
        @cos(pitch) * @sin(yaw),
        @sin(pitch),
        -@cos(pitch) * @cos(yaw),
    );
}

pub fn deinit(ptr: *anyopaque) void {
    const self: *Camera = @ptrCast(@alignCast(ptr));
    _ = self;
}
