const std = @import("std");
const zalg = @import("zalgebra");
const c = @import("../c.zig");
const Scene = @import("Scene.zig");
const SceneObjects = @import("../graphics/SceneObject.zig");
const Camera = @import("../graphics/Camera.zig");
const Window = @import("../Window.zig");
const Input = @import("../Input.zig");

const Axis = @import("../graphics/objects/Axis.zig");
const Triangle = @import("../graphics/objects/Triangle.zig");
const Plane = @import("../graphics/objects/Plane.zig");
const Cube = @import("../graphics/objects/Cube.zig");
const MovingBuilding = @import("../graphics/objects/MovingBuilding.zig");
const Skybox = @import("../graphics/objects/Skybox.zig");

const Io = std.Io;
const gl = c.glad;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const City = @This();

const vtable: Scene.VTable = .{
    .render = render,
    .update = update,
    .deinit = deinit,
};

camera: Camera,
scene_objects: ArrayList(SceneObjects) = .empty,

pub fn init(
    io: Io,
    allocator: Allocator,
    window: *Window,
    input: *Input,
) !City {
    var self: City = .{
        .camera = .{
            .window = window,
            .input = input,
        },
    };
    try self.camera.init();
    self.camera.transform.position = zalg.Vec3.new(25, 25, 25);

    const plane = try Plane.init(io, allocator);
    errdefer plane.sceneObject().deinit(allocator);
    plane.transform.scale.data[0] = 9;
    plane.transform.scale.data[2] = 9;

    plane.transform.position.data[0] = 7;
    plane.transform.position.data[2] = 7;

    try self.scene_objects.append(allocator, plane.sceneObject());

    const skybox = try Skybox.init(
        io,
        allocator,
        "assets/textures/sky.png",
    );
    errdefer skybox.sceneObject().deinit(allocator);
    try self.scene_objects.append(allocator, skybox.sceneObject());

    const axis = try Axis.init(
        io,
        allocator,
    );
    errdefer axis.sceneObject().deinit(allocator);
    axis.transform.scale = axis.transform.scale.scale(10);
    axis.enable = false;
    try self.scene_objects.append(allocator, axis.sceneObject());

    const rng_impl: std.Random.IoSource = .{ .io = io };
    const rand = rng_impl.interface();

    const spacing_scaler: f32 = 3.14;

    for (0..5) |i| {
        for (0..5) |j| {
            const tex = rand.intRangeAtMost(u8, 0, 5);

            const file_name = try std.fmt.allocPrintSentinel(allocator, "assets/textures/facade{}.jpg", .{tex}, 0);
            defer allocator.free(file_name);
            const moving_building = try MovingBuilding.init(
                io,
                allocator,
                file_name,
            );
            moving_building.transform.scale.data[1] = 1 + (rand.float(f32) * 5);
            errdefer moving_building.sceneObject().deinit(allocator);

            const rot: f32 = @as(
                f32,
                @floatFromInt(rand.intRangeAtMost(i32, -30, 30)),
            );
            const x_dif: f32 = @as(
                f32,
                @floatFromInt(rand.intRangeAtMost(i32, 0, 1000)),
            ) / 1000.0;
            const z_dif: f32 = @as(
                f32,
                @floatFromInt(rand.intRangeAtMost(i32, 0, 1000)),
            ) / 1000.0;

            moving_building.transform.rotation.data[1] += rot;

            moving_building.transform.position.data[0] += (@as(f32, @floatFromInt(i)) * spacing_scaler) + x_dif;
            moving_building.transform.position.data[2] += (@as(f32, @floatFromInt(j)) * spacing_scaler) + z_dif;
            try self.scene_objects.append(allocator, moving_building.sceneObject());
        }
    }

    gl.glClearColor(0.3, 0.4, 0.5, 0.0); // Background
    //
    return self;
}

pub fn render(ptr: *anyopaque) void {
    const self: *City = @ptrCast(@alignCast(ptr));

    const view = self.camera.viewMatrix();
    const projection = self.camera.projectionMatrix();

    for (self.scene_objects.items) |item| {
        item.render(view, projection);
    }
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *City = @ptrCast(@alignCast(ptr));

    self.camera.update(dt);
    for (self.scene_objects.items) |item| {
        item.update(dt);
    }
}

pub fn scene(self: *City) Scene {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *City = @ptrCast(@alignCast(ptr));
    for (self.scene_objects.items) |item| {
        item.deinit(allocator);
    }
    self.scene_objects.deinit(allocator);
}
