const std = @import("std");
const zalg = @import("zalgebra");

const Window = @import("Window.zig");
const Input = @import("Input.zig");
const City = @import("scene/City.zig");

const Io = std.Io;
const Timestamp = Io.Timestamp;

var fps_timer: f32 = 0.0;
var frame_count: u32 = 0;
var fps: f32 = 0.0;

pub fn run(io: Io, allocator: std.mem.Allocator) !void {
    var window = try Window.init();
    defer window.deinit();

    window.vsync(false);

    var input: Input = undefined;
    input.init(&window);

    var scene_impl: City = try .init(io, allocator, &window, &input);

    const scene = scene_impl.scene();
    defer scene.deinit(allocator);

    var last = Timestamp.now(io, .awake);
    while (!window.shouldClose()) {
        const dt: f32 = getDt(io, &last);
        calcFps(dt);

        window.clear();
        window.poll();

        scene.update(dt);
        scene.render();

        window.swapBuffers();

        input.endFrame();
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
