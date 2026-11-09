const std = @import("std");
const zalg = @import("zalgebra");
const c = @import("../c.zig");
const Scene = @import("Scene.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const ShaderManager = @import("../graphics/ShaderManager.zig");
const TextureManager = @import("../graphics/TextureManager.zig");
const Camera = @import("../graphics/Camera.zig");
const RenderContext = @import("../graphics/RenderContext.zig");
const Transform = @import("../graphics/Transform.zig");
const FrameBuffer = @import("../graphics/opengl/FrameBuffer.zig");
const Texture = @import("../graphics/opengl/Texture.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

const Mesh = @import("../graphics/objects/Mesh.zig");
const Skybox = @import("../graphics/objects/Skybox.zig");
const Light = @import("../graphics/light.zig").Light;
const obj_loader = @import("../graphics/obj_loader.zig");

const Io = std.Io;
const gl = c.glad;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const FishTower = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .enter = enter,
    .deinit = deinit,
};

const light_position = zalg.Vec3.new(4, 14, 5);
const light_intensity = zalg.Vec3.new(300, 300, 300);

camera: Camera,
scene_objects: ArrayList(SceneObjects) = .empty,
shaders: ShaderManager = undefined,
textures: TextureManager = undefined,
light: Light = undefined,
shadow_map: FrameBuffer = undefined,

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !*FishTower {
    const self = try allocator.create(FishTower);
    errdefer allocator.destroy(self);

    self.* = .{
        .camera = .{
            .window = window,
            .input = input,
        },
    };
    try self.camera.init();
    self.camera.transform.position = zalg.Vec3.new(0, 6, 22);
    self.camera.transform.rotation = zalg.Vec3.new(-0.15, 0, 0);

    self.shaders = try ShaderManager.init(io, allocator);
    errdefer self.shaders.deinit();

    self.textures = TextureManager.init(io, allocator);
    errdefer self.textures.deinit();

    self.light = .{
        .pointlight = .{
            .position = light_position,
            .intensity = light_intensity,
            .near_plane = 2.0,
            .far_plane = 20.0,
        },
    };

    self.shadow_map = try FrameBuffer.initDepth(2048, 2048);
    errdefer self.shadow_map.deinit();

    errdefer self.deinitObjects(allocator);

    try self.addModel(io, allocator, "models/terrain/terrain.obj", .{
        .position = zalg.Vec3.new(0, -2, 0),
        .scale = zalg.Vec3.new(6, 6, 6),
    });
    try self.addModel(io, allocator, "models/tower/tower.obj", .{
        .position = zalg.Vec3.new(0, -0.8, 0),
    });
    try self.addModel(io, allocator, "models/fish/fish.obj", .{
        .position = zalg.Vec3.new(0, 6.9, 0),
        .rotation = zalg.Vec3.new(0, std.math.pi / 2.0, 0),
        .scale = zalg.Vec3.new(0.1, 0.1, 0.1),
    });

    const skybox = try Skybox.init(
        allocator,
        &self.shaders.skybox,
        try self.textures.get("textures/skybox/sky.png", .skybox),
    );
    errdefer skybox.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, skybox.sceneObject());

    gl.glClearColor(0.2, 0.2, 0.25, 0.0); // Background

    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *FishTower = @ptrCast(@alignCast(ptr));

    const ctx: RenderContext = .{
        .view = self.camera.viewMatrix(),
        .projection = self.camera.projectionMatrix(),
        .light = &self.light,
        .light_view_projection = self.light.viewProjectionMatrix(),
    };

    // for shadows
    self.shadow_map.beginDepthPass();
    for (self.scene_objects.items) |item| {
        item.renderShadow(ctx);
    }
    self.shadow_map.endDepthPass();

    // regular render
    self.shadow_map.depth.bind(RenderContext.shadow_map_unit);
    for (self.scene_objects.items) |item| {
        item.render(ctx);
    }
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *FishTower = @ptrCast(@alignCast(ptr));

    self.camera.update(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

pub fn enter(ptr: *anyopaque) void {
    const self: *FishTower = @ptrCast(@alignCast(ptr));
    if (self.camera.input) |input| input.captureCursor(true);
}

pub fn scene(self: *FishTower) Scene {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *FishTower = @ptrCast(@alignCast(ptr));
    self.deinitObjects(allocator);
    self.shaders.deinit();
    self.textures.deinit();
    self.shadow_map.deinit();

    allocator.destroy(self);
}

fn addModel(
    self: *FishTower,
    io: Io,
    allocator: Allocator,
    path: []const u8,
    transform: Transform,
) !void {
    var model = try obj_loader.load(io, allocator, path);
    defer model.deinit();

    for (model.parts) |part| {
        const mesh = try Mesh.init(
            allocator,
            &self.shaders.lit,
            &self.shaders.depth,
            part.data,
        );
        errdefer mesh.sceneObject().deinit(allocator);

        mesh.transform = transform;
        mesh.material = .{
            .diffuse_colour = part.diffuse_colour,
            .diffuse_texture = try self.loadTexture(part),
        };

        try self.scene_objects.append(allocator, mesh.sceneObject());
    }
}

fn loadTexture(self: *FishTower, part: obj_loader.Part) !?*const Texture {
    const path = part.texture_path orelse return null;

    return self.textures.get(path, .material) catch |err| switch (err) {
        error.TextureLoadFailed => null,
        else => |other| return other,
    };
}

fn deinitObjects(self: *FishTower, allocator: Allocator) void {
    for (self.scene_objects.items) |item| {
        item.deinit(allocator);
    }
    self.scene_objects.deinit(allocator);
}
