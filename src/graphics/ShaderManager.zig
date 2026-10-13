const std = @import("std");
const Shader = @import("opengl/Shader.zig");

const Io = std.Io;

const ShaderManger = @This();

axis: Shader,
building: Shader,
cube: Shader,
plane: Shader,
skybox: Shader,
triangle: Shader,

pub fn init(
    io: Io,
    allocator: std.mem.Allocator,
) !ShaderManger {
    var axis = try Shader.init(
        io,
        allocator,
        "assets/shaders/axis.vert",
        "assets/shaders/axis.frag",
    );
    errdefer axis.deinit();

    var building = try Shader.init(
        io,
        allocator,
        "assets/shaders/building.vert",
        "assets/shaders/building.frag",
    );
    errdefer building.deinit();

    var cube = try Shader.init(
        io,
        allocator,
        "assets/shaders/cube.vert",
        "assets/shaders/cube.frag",
    );
    errdefer cube.deinit();

    var plane = try Shader.init(
        io,
        allocator,
        "assets/shaders/plane.vert",
        "assets/shaders/plane.frag",
    );
    errdefer plane.deinit();

    var skybox = try Shader.init(
        io,
        allocator,
        "assets/shaders/skybox.vert",
        "assets/shaders/skybox.frag",
    );
    errdefer skybox.deinit();

    var triangle = try Shader.init(
        io,
        allocator,
        "assets/shaders/triangle.vert",
        "assets/shaders/triangle.frag",
    );
    errdefer triangle.deinit();

    return .{
        .axis = axis,
        .building = building,
        .cube = cube,
        .plane = plane,
        .skybox = skybox,
        .triangle = triangle,
    };
}

pub fn deinit(self: *ShaderManger) void {
    self.axis.deinit();
    self.building.deinit();
    self.cube.deinit();
    self.plane.deinit();
    self.skybox.deinit();
    self.triangle.deinit();
}
