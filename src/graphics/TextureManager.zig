const std = @import("std");
const Texture = @import("opengl/Texture.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const TextureManager = @This();

const assets_root = "assets";

pub const Kind = enum {
    material,
    skybox,
};

io: Io,
allocator: Allocator,
textures: std.StringHashMapUnmanaged(*Texture) = .empty,

pub fn init(io: Io, allocator: Allocator) TextureManager {
    return .{
        .io = io,
        .allocator = allocator,
    };
}

pub fn get(self: *TextureManager, path: []const u8, kind: Kind) !*Texture {
    if (self.textures.get(path)) |texture| {
        return texture;
    }

    const full_path = try std.fs.path.join(
        self.allocator,
        &.{ assets_root, path },
    );
    defer self.allocator.free(full_path);

    const texture = try self.allocator.create(Texture);
    errdefer self.allocator.destroy(texture);

    texture.* = switch (kind) {
        .material => try Texture.initTileBox(self.io, self.allocator, full_path),
        .skybox => try Texture.initSkybox(self.io, self.allocator, full_path),
    };
    errdefer texture.deinit();

    const key = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(key);

    try self.textures.put(self.allocator, key, texture);

    return texture;
}

pub fn deinit(self: *TextureManager) void {
    var entries = self.textures.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.*.deinit();
        self.allocator.destroy(entry.value_ptr.*);
        self.allocator.free(entry.key_ptr.*);
    }

    self.textures.deinit(self.allocator);
}
