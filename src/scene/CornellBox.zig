const std = @import("std");
const zalg = @import("zalgebra");
const c = @import("../c.zig");
const Scene = @import("Scene.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const ShaderManager = @import("../graphics/ShaderManager.zig");
const TextureManager = @import("../graphics/TextureManager.zig");
const Camera = @import("../graphics/Camera.zig");
const RenderContext = @import("../graphics/RenderContext.zig");
const FrameBuffer = @import("../graphics/opengl/FrameBuffer.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

//const Axis = @import("../graphics/objects/Axis.zig");
const Mesh = @import("../graphics/objects/Mesh.zig");
const Light = @import("../graphics/light.zig").Light;

const Io = std.Io;
const gl = c.glad;
const glfw = c.glfw;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const CornellBox = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .enter = enter,
    .deinit = deinit,
};

const wave500 = zalg.Vec3.new(0.0, 255.0, 146.0);
const wave600 = zalg.Vec3.new(255.0, 190.0, 0.0);
const wave700 = zalg.Vec3.new(205.0, 0.0, 0.0);

const light_intensity: zalg.Vec3 = wave500.scale(8.0)
    .add(wave600.scale(15.6))
    .add(wave700.scale(18.4))
    .scale(5.0);

const light_home = zalg.Vec3.new(-275, 500, -275);
const light_speed: f32 = 150.0;
const light_range: f32 = 90.0;

const cornell_box_positions: [60]f32 = .{
    // Floor
    -552.8, 0.0,   0.0,
    0.0,    0.0,   0.0,
    0.0,    0.0,   -559.2,
    -549.6, 0.0,   -559.2,

    // Ceiling
    -556.0, 548.8, 0.0,
    -556.0, 548.8, -559.2,
    0.0,    548.8, -559.2,
    0.0,    548.8, 0.0,

    // Left wall
    -552.8, 0.0,   0.0,
    -549.6, 0.0,   -559.2,
    -556.0, 548.8, -559.2,
    -556.0, 548.8, 0.0,

    // Right wall
    0.0,    0.0,   -559.2,
    0.0,    0.0,   0.0,
    0.0,    548.8, 0.0,
    0.0,    548.8, -559.2,

    // Back wall
    -549.6, 0.0,   -559.2,
    0.0,    0.0,   -559.2,
    0.0,    548.8, -559.2,
    -556.0, 548.8, -559.2,
};

const cornell_box_colours: [60]f32 = .{
    // Floor, white
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Ceiling, white
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Left wall, red
    1.0, 0.0, 0.0,
    1.0, 0.0, 0.0,
    1.0, 0.0, 0.0,
    1.0, 0.0, 0.0,

    // Right wall, green
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,

    // Back wall, white
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
};

const cornell_small_block_positions: [60]f32 = .{
    // Top
    -130.0, 165.0, -65.0,
    -82.0,  165.0, -225.0,
    -240.0, 165.0, -272.0,
    -290.0, 165.0, -114.0,

    // Side 1
    -290.0, 0.0,   -114.0,
    -290.0, 165.0, -114.0,
    -240.0, 165.0, -272.0,
    -240.0, 0.0,   -272.0,

    // Side 2
    -130.0, 0.0,   -65.0,
    -130.0, 165.0, -65.0,
    -290.0, 165.0, -114.0,
    -290.0, 0.0,   -114.0,

    // Side 3
    -82.0,  0.0,   -225.0,
    -82.0,  165.0, -225.0,
    -130.0, 165.0, -65.0,
    -130.0, 0.0,   -65.0,

    // Side 4
    -240.0, 0.0,   -272.0,
    -240.0, 165.0, -272.0,
    -82.0,  165.0, -225.0,
    -82.0,  0.0,   -225.0,
};

const cornell_tall_block_positions: [60]f32 = .{
    // Top
    -423.0, 330.0, -247.0,
    -265.0, 330.0, -296.0,
    -314.0, 330.0, -456.0,
    -472.0, 330.0, -406.0,

    // Side 1
    -423.0, 0.0,   -247.0,
    -423.0, 330.0, -247.0,
    -472.0, 330.0, -406.0,
    -472.0, 0.0,   -406.0,

    // Side 2
    -472.0, 0.0,   -406.0,
    -472.0, 330.0, -406.0,
    -314.0, 330.0, -456.0,
    -314.0, 0.0,   -456.0,

    // Side 3
    -314.0, 0.0,   -456.0,
    -314.0, 330.0, -456.0,
    -265.0, 330.0, -296.0,
    -265.0, 0.0,   -296.0,

    // Side 4
    -265.0, 0.0,   -296.0,
    -265.0, 330.0, -296.0,
    -423.0, 330.0, -247.0,
    -423.0, 0.0,   -247.0,
};

const cornell_block_colours: [60]f32 = .{
    // Top
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Side 1
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Side 2
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Side 3
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,

    // Side 4
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
    1.0, 1.0, 1.0,
};

const cornell_indicies: [30]u32 = .{
    0,  1,  2,
    0,  2,  3,

    4,  5,  6,
    4,  6,  7,

    8,  9,  10,
    8,  10, 11,

    12, 13, 14,
    12, 14, 15,

    16, 17, 18,
    16, 18, 19,
};

camera: Camera,
scene_objects: ArrayList(SceneObjects) = .empty,
shaders: ShaderManager = undefined,
textures: TextureManager = undefined,
light: Light = undefined,
shadow_map: FrameBuffer = undefined,
input: *Input,
light_offset: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !*CornellBox {
    const self = try allocator.create(CornellBox);
    errdefer allocator.destroy(self);

    self.* = .{
        .camera = .{
            .window = window,
            .input = null,
            .near_plane = 600,
            .far_plane = 1500,
        },
        .input = input,
    };
    try self.camera.init();
    self.camera.transform.position = zalg.Vec3.new(-278, 273, 800);
    self.camera.transform.rotation = zalg.Vec3.new(0, 0, 0);

    self.shaders = try ShaderManager.init(io, allocator);
    errdefer self.shaders.deinit();

    self.textures = TextureManager.init(io, allocator);
    errdefer self.textures.deinit();

    self.light = .{
        .pointlight = .{
            .position = light_home,
            .intensity = light_intensity,
        },
    };

    self.shadow_map = try FrameBuffer.initDepth(2048, 2048);
    errdefer self.shadow_map.deinit();

    // const axis = try Axis.init(
    //     allocator,
    //     &self.shaders.axis,
    // );
    // errdefer axis.sceneObject().deinit(allocator);
    // axis.transform.scale = axis.transform.scale.scale(10);
    // axis.enable = true;
    // try self.scene_objects.append(allocator, axis.sceneObject());

    const cornell_box = try Mesh.init(
        allocator,
        &self.shaders.cornell,
        &self.shaders.depth,
        .{
            .positions = &cornell_box_positions,
            .indices = &cornell_indicies,
            .colours = &cornell_box_colours,
        },
    );
    errdefer cornell_box.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, cornell_box.sceneObject());

    const cornell_tall_block = try Mesh.init(
        allocator,
        &self.shaders.cornell,
        &self.shaders.depth,
        .{
            .positions = &cornell_tall_block_positions,
            .indices = &cornell_indicies,
            .colours = &cornell_block_colours,
        },
    );
    errdefer cornell_tall_block.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, cornell_tall_block.sceneObject());

    const cornell_small_block = try Mesh.init(
        allocator,
        &self.shaders.cornell,
        &self.shaders.depth,
        .{
            .positions = &cornell_small_block_positions,
            .indices = &cornell_indicies,
            .colours = &cornell_block_colours,
        },
    );
    errdefer cornell_small_block.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, cornell_small_block.sceneObject());

    gl.glClearColor(0.2, 0.2, 0.25, 0.0); // Background

    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *CornellBox = @ptrCast(@alignCast(ptr));

    const view = self.camera.viewMatrix();
    const projection = self.camera.projectionMatrix();

    const ctx: RenderContext = .{
        .view = view,
        .projection = projection,
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
    const self: *CornellBox = @ptrCast(@alignCast(ptr));

    self.camera.update(dt);
    self.updateLight(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

fn updateLight(self: *CornellBox, dt: f32) void {
    const keys_down = &self.input.keys_down;
    const amount = light_speed * dt;

    if (keys_down[glfw.GLFW_KEY_LEFT]) {
        self.light_offset.data[0] -= amount;
    }
    if (keys_down[glfw.GLFW_KEY_RIGHT]) {
        self.light_offset.data[0] += amount;
    }
    if (keys_down[glfw.GLFW_KEY_UP]) {
        self.light_offset.data[2] -= amount;
    }
    if (keys_down[glfw.GLFW_KEY_DOWN]) {
        self.light_offset.data[2] += amount;
    }

    self.light_offset.data[0] = std.math.clamp(
        self.light_offset.data[0],
        -light_range,
        light_range,
    );
    self.light_offset.data[2] = std.math.clamp(
        self.light_offset.data[2],
        -light_range,
        light_range,
    );

    self.light.setPosition(light_home.add(self.light_offset));
}

pub fn enter(ptr: *anyopaque) void {
    const self: *CornellBox = @ptrCast(@alignCast(ptr));
    self.input.captureCursor(false);
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
    self.shadow_map.deinit();

    allocator.destroy(self);
}
