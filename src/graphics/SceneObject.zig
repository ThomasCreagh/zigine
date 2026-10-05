const zalg = @import("zalgebra");
const Transform = @import("Transform.zig");

const SceneObject = @This();

ptr: *anyopaque,
vtable: *const VTable,

pub const VTable = struct {
    render: *const fn (
        *anyopaque,
        zalg.Mat4, // view
        zalg.Mat4, // projection
    ) void,
    getTransform: *const fn (*anyopaque) *Transform,
    deinit: *const fn (*anyopaque) void,
};

pub fn render(
    self: SceneObject,
    view: zalg.Mat4,
    projection: zalg.Mat4,
) void {
    self.vtable.render(self.ptr, view, projection);
}

pub fn getTransform(self: SceneObject) *Transform {
    return self.vtable.getTransform(self.ptr);
}

pub fn deinit(self: SceneObject) void {
    self.vtable.deinit(self.ptr);
}
