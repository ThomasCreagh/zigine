const std = @import("std");
const zalg = @import("zalgebra");

const gltf_loader = @import("../graphics/gltf_loader.zig");

const Allocator = std.mem.Allocator;
const Skeleton = @This();

model: *const gltf_loader.Model,
locals: []zalg.Mat4,
globals: []zalg.Mat4,

pub fn init(allocator: Allocator, model: *const gltf_loader.Model) !Skeleton {
    const length = model.nodes.len;

    const locals = try allocator.alloc(zalg.Mat4, length);
    errdefer allocator.free(locals);

    const globals = try allocator.alloc(zalg.Mat4, length);

    var self: Skeleton = .{
        .model = model,
        .locals = locals,
        .globals = globals,
    };

    self.update();

    return self;
}

pub fn update(self: *Skeleton) void {
    for (self.model.node_order) |i| {
        const node = self.model.nodes[i];
        if (node.matrix) |matrix| {
            self.locals[i] = matrix;
        } else {
            self.locals[i] = zalg.Mat4.fromTranslate(node.translation)
                .mul(node.rotation.toMat4())
                .mul(zalg.Mat4.fromScale(node.scale));
        }
        if (node.parent) |parent| {
            self.globals[i] = self.globals[parent].mul(self.locals[i]);
        } else {
            self.globals[i] = self.locals[i];
        }
    }
}

pub fn deinit(self: *Skeleton, allocator: Allocator) void {
    allocator.free(self.locals);
    allocator.free(self.globals);
}
