const std = @import("std");
const Shader = @import("opengl/Shader.zig");

const Io = std.Io;

const ShaderManager = @This();

axis: Shader,
skybox: Shader,
cornell: Shader,
depth: Shader,

pub fn init(
    io: Io,
    allocator: std.mem.Allocator,
) !ShaderManager {
    var axis = try Shader.init(
        io,
        allocator,
        "assets/shaders/axis.vert",
        "assets/shaders/axis.frag",
    );
    errdefer axis.deinit();

    var skybox = try Shader.init(
        io,
        allocator,
        "assets/shaders/skybox.vert",
        "assets/shaders/skybox.frag",
    );
    errdefer skybox.deinit();

    var cornell = try Shader.init(
        io,
        allocator,
        "assets/shaders/cornell.vert",
        "assets/shaders/cornell.frag",
    );
    errdefer cornell.deinit();

    var depth = try Shader.init(
        io,
        allocator,
        "assets/shaders/depth.vert",
        "assets/shaders/depth.frag",
    );
    errdefer depth.deinit();

    return .{
        .axis = axis,
        .skybox = skybox,
        .cornell = cornell,
        .depth = depth,
    };
}

pub fn deinit(self: *ShaderManager) void {
    self.axis.deinit();
    self.skybox.deinit();
    self.cornell.deinit();
    self.depth.deinit();
}
