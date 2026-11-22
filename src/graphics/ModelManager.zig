const std = @import("std");
const gltf_loader = @import("gltf_loader.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const ModelManager = @This();

io: Io,
allocator: Allocator,
models: std.StringHashMapUnmanaged(*gltf_loader.Model) = .empty,

pub fn init(io: Io, allocator: Allocator) ModelManager {
    return .{
        .io = io,
        .allocator = allocator,
    };
}

pub fn get(self: *ModelManager, path: []const u8) !*const gltf_loader.Model {
    if (self.models.get(path)) |model| {
        return model;
    }

    const model = try self.allocator.create(gltf_loader.Model);
    errdefer self.allocator.destroy(model);

    model.* = try gltf_loader.load(self.io, self.allocator, path);
    errdefer model.deinit();

    const key = try self.allocator.dupe(u8, path);
    errdefer self.allocator.free(key);

    try self.models.put(self.allocator, key, model);

    return model;
}

pub fn deinit(self: *ModelManager) void {
    var entries = self.models.iterator();
    while (entries.next()) |entry| {
        entry.value_ptr.*.deinit();
        self.allocator.destroy(entry.value_ptr.*);
        self.allocator.free(entry.key_ptr.*);
    }

    self.models.deinit(self.allocator);
}
