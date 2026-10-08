const std = @import("std");
const zalg = @import("zalgebra");
const Transform = @import("Transform.zig");

const Allocator = std.mem.Allocator;
const SceneObject = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    render: *const fn (
        *anyopaque,
        zalg.Mat4, // view
        zalg.Mat4, // projection
    ) void,
    update: *const fn (*anyopaque, f32) void,
    getTransform: *const fn (*anyopaque) *Transform,
    deinit: *const fn (*anyopaque, Allocator) void,
};

pub fn render(
    self: SceneObject,
    view: zalg.Mat4,
    projection: zalg.Mat4,
) void {
    self.vtable.render(self.ptr, view, projection);
}

pub fn update(self: SceneObject, dt: f32) void {
    self.vtable.update(self.ptr, dt);
}

pub fn getTransform(self: SceneObject) *Transform {
    return self.vtable.getTransform(self.ptr);
}

pub fn deinit(self: SceneObject, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}
