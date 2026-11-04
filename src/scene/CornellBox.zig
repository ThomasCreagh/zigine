const std = @import("std");
const zalg = @import("zalgebra");
const c = @import("../c.zig");
const Scene = @import("Scene.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const ShaderManager = @import("../graphics/ShaderManager.zig");
const TextureManager = @import("../graphics/TextureManager.zig");
const Camera = @import("../graphics/Camera.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

const Axis = @import("../graphics/objects/Axis.zig");
const Triangle = @import("../graphics/objects/Triangle.zig");
const Plane = @import("../graphics/objects/Plane.zig");
const WhiteCube = @import("../graphics/objects/WhiteCube.zig");
const CornellEnclosure = @import("../graphics/objects/CornellEnclosure.zig");
const Skybox = @import("../graphics/objects/Skybox.zig");

const Io = std.Io;
const gl = c.glad;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const CornellBox = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .deinit = deinit,
};

camera: Camera,
scene_objects: ArrayList(SceneObjects) = .empty,
shaders: ShaderManager = undefined,
textures: TextureManager = undefined,

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !*CornellBox {
    _ = input;
    const self = try allocator.create(CornellBox);
    errdefer allocator.destroy(self);

    self.* = .{
        .camera = .{
            .window = window,
            .input = null,
        },
    };
    try self.camera.init();
    self.camera.transform.position = zalg.Vec3.new(0, 0, 9);
    self.camera.transform.rotation = zalg.Vec3.new(0, 0, 0);

    self.shaders = try ShaderManager.init(io, allocator);
    errdefer self.shaders.deinit();

    self.textures = try TextureManager.init();
    errdefer self.textures.deinit();

    const axis = try Axis.init(
        allocator,
        &self.shaders.axis,
    );
    errdefer axis.sceneObject().deinit(allocator);
    axis.transform.scale = axis.transform.scale.scale(10);
    axis.enable = true;
    try self.scene_objects.append(allocator, axis.sceneObject());

    const enclosure = try CornellEnclosure.init(
        allocator,
        &self.shaders.cube,
    );
    errdefer enclosure.sceneObject().deinit(allocator);
    enclosure.transform.scale = zalg.Vec3.new(4, 4, 8);
    try self.scene_objects.append(allocator, enclosure.sceneObject());

    const cube_0 = try WhiteCube.init(
        allocator,
        &self.shaders.cube,
    );
    errdefer cube_0.sceneObject().deinit(allocator);
    cube_0.transform.scale = zalg.Vec3.new(1, 2, 1);
    cube_0.transform.position = zalg.Vec3.new(0, -2, 0);
    try self.scene_objects.append(allocator, cube_0.sceneObject());

    const cube_1 = try WhiteCube.init(
        allocator,
        &self.shaders.cube,
    );
    errdefer cube_1.sceneObject().deinit(allocator);
    cube_1.transform.position = zalg.Vec3.new(0, -2, 0);
    try self.scene_objects.append(allocator, cube_1.sceneObject());

    gl.glClearColor(0.3, 0.4, 0.5, 0.0); // Background

    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *CornellBox = @ptrCast(@alignCast(ptr));

    const view = self.camera.viewMatrix();
    const projection = self.camera.projectionMatrix();

    for (self.scene_objects.items) |item| {
        item.render(view, projection);
    }
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *CornellBox = @ptrCast(@alignCast(ptr));

    self.camera.update(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

pub fn scene(self: *CornellBox) Scene {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *CornellBox = @ptrCast(@alignCast(ptr));
    for (self.scene_objects.items) |item| {
        item.deinit(allocator);
    }
    self.scene_objects.deinit(allocator);
    self.shaders.deinit();
    self.textures.deinit();

    allocator.destroy(self);
}
