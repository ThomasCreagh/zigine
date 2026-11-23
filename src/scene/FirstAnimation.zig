const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const zalg = @import("zalgebra");

const c = @import("../c.zig");
const gl = c.glad;
const glfw = c.glfw;
const Camera = @import("../graphics/Camera.zig");
const Light = @import("../graphics/light.zig").Light;
const ModelManager = @import("../graphics/ModelManager.zig");
const AnimatedModel = @import("../graphics/objects/AnimatedModel.zig");
const Mesh = @import("../graphics/objects/Mesh.zig");
const Skybox = @import("../graphics/objects/Skybox.zig");
const FrameBuffer = @import("../graphics/opengl/FrameBuffer.zig");
const Texture = @import("../graphics/opengl/Texture.zig");
const RenderContext = @import("../graphics/RenderContext.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const ShaderManager = @import("../graphics/ShaderManager.zig");
const TextureManager = @import("../graphics/TextureManager.zig");
const Transform = @import("../graphics/Transform.zig");
const Input = @import("../Input.zig");
const Window = @import("../Window.zig");
const Scene = @import("Scene.zig");

const FirstAnimation = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .enter = enter,
    .getBackground = getBackground,
    .deinit = deinit,
};

const light_position = zalg.Vec3.new(-254, 600, 0); // (-275, 500, 800);
const light_intensity = zalg.Vec3.new(1e6, 1e6, 1e6); // (5e6, 5e6, 5e6);

const floor_positions: [12]f32 = .{
    -1050.0, -10.6, 800.0,
    550.0,   -10.6, 800.0,
    550.0,   -10.6, -800.0,
    -1050.0, -10.6, -800.0,
};

const floor_indices: [6]u32 = .{
    0, 1, 2,
    0, 2, 3,
};

camera: Camera,
input: *Input,
scene_objects: ArrayList(SceneObjects) = .empty,
shaders: ShaderManager = undefined,
textures: TextureManager = undefined,
models: ModelManager = undefined,
light: Light = undefined,
shadow_map: FrameBuffer = undefined,
background: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),
bot: *AnimatedModel = undefined,

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !*FirstAnimation {
    const self = try allocator.create(FirstAnimation);
    errdefer allocator.destroy(self);

    self.* = .{
        .camera = .{
            .window = window,
            .input = null,
        },
        .input = input,
    };

    try self.camera.init();

    self.camera.transform.position = zalg.Vec3.new(-254, 350, 650);
    self.camera.transform.rotation = zalg.Vec3.new(-0.3, 0, 0);
    self.camera.near_plane = 100;
    self.camera.far_plane = 2500;
    self.camera.position_speed = 500;

    self.shaders = try ShaderManager.init(io, allocator);
    errdefer self.shaders.deinit();

    self.textures = TextureManager.init(io, allocator);
    errdefer self.textures.deinit();

    self.models = ModelManager.init(io, allocator);
    errdefer self.models.deinit();

    self.light = .{
        .pointlight = .{
            .position = light_position,
            .intensity = light_intensity,
            .near_plane = 300.0,
            .far_plane = 800.0,
        },
    };

    self.shadow_map = try FrameBuffer.initDepth(2048, 2048);
    errdefer self.shadow_map.deinit();

    errdefer self.deinitObjects(allocator);

    const floor = try Mesh.init(
        allocator,
        &self.shaders.lit,
        &self.shaders.depth,
        .{
            .positions = &floor_positions,
            .indices = &floor_indices,
        },
    );
    errdefer floor.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, floor.sceneObject());

    self.bot = try self.addAnimatedModel(allocator, "models/bot/bot.gltf", .{});
    self.bot.play(0);

    const breakdance_dancer = try self.addAnimatedModel(allocator, "models/breakdance/breakdance.glb", .{
        .position = zalg.Vec3.new(-400, -10.6, -100),
        .scale = zalg.Vec3.new(100, 100, 100),
    });
    breakdance_dancer.play(0);

    const flair_dancer = try self.addAnimatedModel(allocator, "models/flair/flair.glb", .{
        .position = zalg.Vec3.new(-200, -10.6, -100),
        .scale = zalg.Vec3.new(100, 100, 100),
    });
    flair_dancer.play(0);

    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *FirstAnimation = @ptrCast(@alignCast(ptr));

    const ctx: RenderContext = .{
        .view = self.camera.viewMatrix(),
        .projection = self.camera.projectionMatrix(),
        .lighting = .{
            .light = &self.light,
            .shadow_view_projection = self.light.viewProjectionMatrix(),
        },
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
    const self: *FirstAnimation = @ptrCast(@alignCast(ptr));

    self.updateAnimation();

    self.camera.update(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

pub fn enter(ptr: *anyopaque) void {
    const self: *FirstAnimation = @ptrCast(@alignCast(ptr));
    self.input.captureCursor(self.camera.input != null);
}

pub fn scene(self: *FirstAnimation) Scene {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn getBackground(ptr: *anyopaque) zalg.Vec3 {
    const self: *FirstAnimation = @ptrCast(@alignCast(ptr));
    return self.background;
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *FirstAnimation = @ptrCast(@alignCast(ptr));
    self.deinitObjects(allocator);
    self.shaders.deinit();
    self.textures.deinit();
    self.models.deinit();
    self.shadow_map.deinit();

    allocator.destroy(self);
}

fn updateAnimation(self: *FirstAnimation) void {
    if (self.input.wasPressed(glfw.GLFW_KEY_Z)) {
        self.bot.play(0);
    } else if (self.input.wasPressed(glfw.GLFW_KEY_X)) {
        self.bot.play(1);
    }
}

fn addAnimatedModel(
    self: *FirstAnimation,
    allocator: Allocator,
    path: []const u8,
    transform: Transform,
) !*AnimatedModel {
    const model = try self.models.get(path);

    const animated_model = try AnimatedModel.init(
        allocator,
        &self.shaders.lit,
        &self.shaders.depth,
        model,
    );
    errdefer animated_model.sceneObject().deinit(allocator);

    animated_model.transform = transform;

    try self.scene_objects.append(allocator, animated_model.sceneObject());

    return animated_model;
}

fn deinitObjects(self: *FirstAnimation, allocator: Allocator) void {
    for (self.scene_objects.items) |item| {
        item.deinit(allocator);
    }
    self.scene_objects.deinit(allocator);
}
