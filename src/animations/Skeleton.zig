const std = @import("std");
const zalg = @import("zalgebra");

const gltf_loader = @import("../graphics/gltf_loader.zig");

const Allocator = std.mem.Allocator;
const Skeleton = @This();

model: *const gltf_loader.Model,
translations: []zalg.Vec3,
rotations: []zalg.Quat,
scales: []zalg.Vec3,
locals: []zalg.Mat4,
globals: []zalg.Mat4,
joint_matrices: [][]zalg.Mat4,
joint_buffer: []zalg.Mat4,

pub fn init(allocator: Allocator, model: *const gltf_loader.Model) !Skeleton {
    const length = model.nodes.len;

    const translations = try allocator.alloc(zalg.Vec3, length);
    errdefer allocator.free(translations);

    const rotations = try allocator.alloc(zalg.Quat, length);
    errdefer allocator.free(rotations);

    const scales = try allocator.alloc(zalg.Vec3, length);
    errdefer allocator.free(scales);

    for (model.nodes, translations, rotations, scales) |node, *translation, *rotation, *scale| {
        translation.* = node.translation;
        rotation.* = node.rotation;
        scale.* = node.scale;
    }

    const locals = try allocator.alloc(zalg.Mat4, length);
    errdefer allocator.free(locals);

    const globals = try allocator.alloc(zalg.Mat4, length);
    errdefer allocator.free(globals);

    var joint_count: usize = 0;
    for (model.skins) |skin| joint_count += skin.joints.len;

    const joint_buffer = try allocator.alloc(zalg.Mat4, joint_count);
    errdefer allocator.free(joint_buffer);

    const joint_matrices = try allocator.alloc([]zalg.Mat4, model.skins.len);

    var start: usize = 0;
    for (model.skins, joint_matrices) |skin, *matrices| {
        matrices.* = joint_buffer[start..][0..skin.joints.len];
        start += skin.joints.len;
    }

    var self: Skeleton = .{
        .model = model,
        .translations = translations,
        .rotations = rotations,
        .scales = scales,
        .locals = locals,
        .globals = globals,
        .joint_matrices = joint_matrices,
        .joint_buffer = joint_buffer,
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
            self.locals[i] = zalg.Mat4.fromTranslate(self.translations[i])
                .mul(self.rotations[i].toMat4())
                .mul(zalg.Mat4.fromScale(self.scales[i]));
        }
        if (node.parent) |parent| {
            self.globals[i] = self.globals[parent].mul(self.locals[i]);
        } else {
            self.globals[i] = self.locals[i];
        }
    }

    for (self.model.skins, self.joint_matrices) |skin, matrices| {
        for (skin.joints, skin.inverse_bind_matrices, matrices) |joint, inverse_bind, *matrix| {
            matrix.* = self.globals[joint].mul(inverse_bind);
        }
    }
}

pub fn deinit(self: *Skeleton, allocator: Allocator) void {
    allocator.free(self.translations);
    allocator.free(self.rotations);
    allocator.free(self.scales);
    allocator.free(self.locals);
    allocator.free(self.globals);
    allocator.free(self.joint_matrices);
    allocator.free(self.joint_buffer);
}
