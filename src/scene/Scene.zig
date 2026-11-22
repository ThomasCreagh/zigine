const std = @import("std");
const zalg = @import("zalgebra");

const Allocator = std.mem.Allocator;
const Scene = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    // functions to implement
    render: *const fn (*anyopaque) void,
    enter: *const fn (*anyopaque) void,
    deinit: *const fn (*anyopaque, Allocator) void,
    getBackground: *const fn (*anyopaque) zalg.Vec3,
    // optional to implement
    update: *const fn (*anyopaque, f32) void = noUpdate,
};

// implement
pub fn render(self: Scene) void {
    self.vtable.render(self.ptr);
}

pub fn enter(self: Scene) void {
    self.vtable.enter(self.ptr);
}

pub fn deinit(self: Scene, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}

pub fn getBackground(self: Scene) zalg.Vec3 {
    return self.vtable.getBackground(self.ptr);
}

// optional
pub fn update(self: Scene, dt: f32) void {
    self.vtable.update(self.ptr, dt);
}

// empty functions
fn noUpdate(_: *anyopaque, _: f32) void {}
