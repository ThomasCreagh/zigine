const std = @import("std");

const Transform = @import("../Transform.zig");
const Shader = @import("../opengl/Shader.zig");
const SceneObject = @import("../SceneObject.zig");
const RenderContext = @import("../RenderContext.zig");
const Mesh = @import("Mesh.zig");
const Skeleton = @import("../../animations/Skeleton.zig");
const sampler = @import("../../animations/sampler.zig");
const gltf_loader = @import("../gltf_loader.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const AnimatedModel = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .renderShadow = renderShadow,
    .update = update,
    .getTransform = getTransform,
    .getSkeleton = getSkeleton,
    .deinit = deinit,
};

transform: Transform = .{},
enable: bool = true,
skeleton: Skeleton,
meshes: ArrayList(*Mesh) = .empty,
clip: ?usize = null,
time: f32 = 0,

pub fn init(
    allocator: Allocator,
    program: *Shader,
    depth_program: *Shader,
    model: *const gltf_loader.Model,
) !*AnimatedModel {
    for (model.skins) |skin| {
        if (skin.joints.len == 0 or skin.joints.len > Mesh.max_joints) return error.UnsupportedJointCount;
    }

    const self = try allocator.create(AnimatedModel);
    errdefer allocator.destroy(self);

    self.* = .{
        .skeleton = try Skeleton.init(allocator, model),
    };
    errdefer self.skeleton.deinit(allocator);

    errdefer self.deinitMeshes(allocator);

    for (model.parts) |part| {
        const mesh = try Mesh.init(
            allocator,
            program,
            depth_program,
            part.data,
        );
        errdefer mesh.sceneObject().deinit(allocator);

        mesh.material = .{
            .diffuse_colour = part.diffuse_colour,
            .diffuse_texture = null,
        };
        mesh.skeleton = &self.skeleton;
        mesh.skin = findSkin(model, part.mesh);

        try self.meshes.append(allocator, mesh);
    }

    return self;
}

pub fn render(ptr: *anyopaque, ctx: RenderContext) void {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    for (self.meshes.items) |mesh| {
        mesh.transform = self.transform;
        mesh.sceneObject().render(ctx);
    }
}

pub fn renderShadow(ptr: *anyopaque, ctx: RenderContext) void {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    for (self.meshes.items) |mesh| {
        mesh.transform = self.transform;
        mesh.sceneObject().renderShadow(ctx);
    }
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));

    if (self.clip) |index| {
        const clip = &self.skeleton.model.clips[index];

        if (clip.duration > 0) self.time = @mod(self.time + dt, clip.duration);

        sampler.sample(clip, self.time, &self.skeleton);
    }

    self.skeleton.update();
}

pub fn play(self: *AnimatedModel, clip: usize) void {
    self.clip = clip;
    self.time = 0;
}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn getSkeleton(ptr: *anyopaque) ?*const Skeleton {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));
    return &self.skeleton;
}

pub fn sceneObject(self: *AnimatedModel) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *AnimatedModel = @ptrCast(@alignCast(ptr));
    self.deinitMeshes(allocator);
    self.skeleton.deinit(allocator);
    allocator.destroy(self);
}

fn findSkin(model: *const gltf_loader.Model, mesh: usize) ?usize {
    for (model.nodes) |node| {
        if (node.mesh == mesh) return node.skin;
    }
    return null;
}

fn deinitMeshes(self: *AnimatedModel, allocator: Allocator) void {
    for (self.meshes.items) |mesh| {
        mesh.sceneObject().deinit(allocator);
    }
    self.meshes.deinit(allocator);
}
