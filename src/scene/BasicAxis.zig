const std = @import("std");
const c = @import("../c.zig");
const Scene = @import("Scene.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const Camera = @import("../graphics/Camera.zig");
const Axis = @import("../graphics/objects/Axis.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

const Io = std.Io;
const gl = c.glad;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const BasicAxis = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .deinit = deinit,
};

camera: Camera,
scene_objects: ArrayList(SceneObjects) = .empty,

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !BasicAxis {
    var self: BasicAxis = .{
        .camera = .{
            .window = window,
            .input = input,
        },
    };
    try self.camera.init();

    const axis = try Axis.init(io, allocator);
    errdefer axis.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, axis.sceneObject());

    gl.glClearColor(0.3, 0.4, 0.5, 0.0); // Background

    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *BasicAxis = @ptrCast(@alignCast(ptr));

    const view = self.camera.viewMatrix();
    const projection = self.camera.projectionMatrix();

    for (self.scene_objects.items) |item| {
        item.render(view, projection);
    }
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *BasicAxis = @ptrCast(@alignCast(ptr));

    self.camera.update(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

pub fn scene(self: *BasicAxis) Scene {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *BasicAxis = @ptrCast(@alignCast(ptr));
    for (self.scene_objects.items) |item| {
        item.deinit(allocator);
    }
    self.scene_objects.deinit(allocator);
}
