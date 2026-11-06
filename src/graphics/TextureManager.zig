const std = @import("std");
const c = @import("../c.zig");
const Texture = @import("opengl/Texture.zig");
// const texture_loader = @import("texture_loader.zig");

const gl = c.glad;
const Io = std.Io;

const TextureManager = @This();

facades: [6]Texture,
skybox: Texture,

pub fn init(io: Io, allocator: std.mem.Allocator) !TextureManager {
    var self: TextureManager = undefined;

    self.facades[0] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade0.jpg",
    );
    errdefer self.facades[0].deinit();

    self.facades[1] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade1.jpg",
    );
    errdefer self.facades[1].deinit();

    self.facades[2] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade2.jpg",
    );
    errdefer self.facades[2].deinit();

    self.facades[3] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade3.jpg",
    );
    errdefer self.facades[3].deinit();

    self.facades[4] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade4.jpg",
    );
    errdefer self.facades[4].deinit();

    self.facades[5] = try Texture.initTileBox(
        io,
        allocator,
        "assets/textures/facade5.jpg",
    );
    errdefer self.facades[5].deinit();

    self.skybox = try Texture.initSkybox(
        io,
        allocator,
        "assets/textures/sky.png",
    );
    errdefer self.skybox.deinit();

    return self;
}

pub fn deinit(self: *TextureManager) void {
    for (&self.facades) |*texture| {
        texture.deinit();
    }

    self.skybox.deinit();
}
