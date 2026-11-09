const std = @import("std");
const zalg = @import("zalgebra");
const c = @import("c.zig");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const Scene = @import("scene/Scene.zig");
const BasicAxis = @import("scene/BasicAxis.zig");
const CornellBox = @import("scene/CornellBox.zig");
const FishTower = @import("scene/FishTower.zig");

const Io = std.Io;
const Timestamp = Io.Timestamp;
const ArrayList = std.ArrayList;
const glfw = c.glfw;

pub const obj_loader = @import("graphics/obj_loader.zig");

var fps_timer: f32 = 0.0;
var frame_count: u32 = 0;
var fps: f32 = 0.0;

pub fn run(io: Io, allocator: std.mem.Allocator) !void {
    var window = try Window.init();
    defer window.deinit();

    window.vsync(true);
    window.culling(true);

    var input: Input = undefined;
    input.init(&window);

    var scenes: ArrayList(Scene) = .empty;
    defer scenes.deinit(allocator);

    var fishtower_scene: *FishTower = try .init(io, allocator, &window, &input);
    defer fishtower_scene.scene().deinit(allocator);
    try scenes.append(allocator, fishtower_scene.scene());

    var cornell_scene: *CornellBox = try .init(io, allocator, &window, &input);
    defer cornell_scene.scene().deinit(allocator);
    try scenes.append(allocator, cornell_scene.scene());

    var basic_scene: *BasicAxis = try .init(io, allocator, &window, &input);
    defer basic_scene.scene().deinit(allocator);
    try scenes.append(allocator, basic_scene.scene());

    var scene = fishtower_scene.scene();
    scene.enter();

    var last = Timestamp.now(io, .awake);
    while (!window.shouldClose()) {
        const dt: f32 = getDt(io, &last);
        calcFps(dt);

        window.clear();
        window.poll();

        updateSelectedScene(&input, &scene, scenes);

        scene.update(dt);
        scene.render();

        window.swapBuffers();

        input.endFrame();
    }
}

fn updateSelectedScene(
    input: *const Input,
    scene: *Scene,
    scenes: ArrayList(Scene),
) void {
    if (input.wasPressed(glfw.GLFW_KEY_1)) {
        scene.* = scenes.items[0];
        scene.enter();
    }
    if (input.wasPressed(glfw.GLFW_KEY_2)) {
        scene.* = scenes.items[1];
        scene.enter();
    }
    if (input.wasPressed(glfw.GLFW_KEY_3)) {
        scene.* = scenes.items[2];
        scene.enter();
    }
}

fn getDt(io: Io, last: *Timestamp) f32 {
    const now = Timestamp.now(io, .awake);

    const elapsed = last.durationTo(now);
    last.* = now;

    return @as(
        f32,
        @floatFromInt(elapsed.toNanoseconds()),
    ) / 1_000_000_000.0;
}

fn calcFps(dt: f32) void {
    fps_timer += dt;
    frame_count += 1;

    if (fps_timer >= 1.0) {
        fps = @as(f32, @floatFromInt(frame_count)) / fps_timer;

        std.debug.print("FPS: {d:.1}\n", .{fps});

        fps_timer = 0.0;
        frame_count = 0;
    }
}
