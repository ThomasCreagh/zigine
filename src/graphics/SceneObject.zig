const std = @import("std");
const zalg = @import("zalgebra");
const Transform = @import("Transform.zig");
const RenderContext = @import("RenderContext.zig");
const Skeleton = @import("../animations/Skeleton.zig");

const Allocator = std.mem.Allocator;
const SceneObject = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    // functions to implement
    render: *const fn (*anyopaque, RenderContext) void,
    deinit: *const fn (*anyopaque, Allocator) void,
    getTransform: *const fn (*anyopaque) *Transform,
    // optional to implement
    update: *const fn (*anyopaque, f32) void = noUpdate,
    renderShadow: *const fn (*anyopaque, RenderContext) void = noRenderShadow,
    getSkeleton: *const fn (*anyopaque) ?*const Skeleton = noSkeleton,
};

// implement
pub fn render(
    self: SceneObject,
    ctx: RenderContext,
) void {
    self.vtable.render(self.ptr, ctx);
}

pub fn deinit(self: SceneObject, allocator: Allocator) void {
    self.vtable.deinit(self.ptr, allocator);
}

pub fn getTransform(self: SceneObject) *Transform {
    return self.vtable.getTransform(self.ptr);
}

// optional
pub fn renderShadow(
    self: SceneObject,
    ctx: RenderContext,
) void {
    self.vtable.renderShadow(self.ptr, ctx);
}

pub fn update(self: SceneObject, dt: f32) void {
    self.vtable.update(self.ptr, dt);
}

pub fn getSkeleton(self: SceneObject) ?*const Skeleton {
    return self.vtable.getSkeleton(self.ptr);
}

// empty functions
fn noRenderShadow(_: *anyopaque, _: RenderContext) void {}
fn noUpdate(_: *anyopaque, _: f32) void {}
fn noSkeleton(_: *anyopaque) ?*const Skeleton {
    return null;
}
