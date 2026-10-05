const std = @import("std");
const zalg = @import("zalgebra");

const Allocator = std.mem.Allocator;
const Scene = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    update: *const fn (
        *anyopaque,
        f32,
    ) void,
    render: *const fn (
        *anyopaque,
        zalg.Mat4,
        zalg.Mat4,
    ) void,
    deinit: *const fn (*anyopaque, Allocator) void,
};

pub fn update(self: Scene, dt: f32) void {
    self.vtable.update(self.ptr, dt);
}

pub fn render(
    self: Scene,
) void {
    self.vtable.render(self.ptr);
}

pub fn deinit(self: Scene, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}
