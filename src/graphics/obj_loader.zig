const std = @import("std");
const zalg = @import("zalgebra");
const assets = @import("../assets.zig");
const MeshData = @import("MeshData.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const no_index = std.math.maxInt(u32);

pub const Part = struct {
    name: []const u8,
    data: MeshData,
    diffuse_colour: zalg.Vec3,
    texture_path: ?[]const u8,
};

pub const Model = struct {
    arena: std.heap.ArenaAllocator,
    parts: []Part,

    pub fn deinit(self: *Model) void {
        self.arena.deinit();
    }
};

const MaterialInfo = struct {
    diffuse_colour: zalg.Vec3 = zalg.Vec3.new(1, 1, 1),
    texture_path: ?[]const u8 = null,
};

pub const MaterialMap = std.StringHashMapUnmanaged(MaterialInfo);

const Corner = struct {
    v: u32,
    vt: u32,
    vn: u32,
};

const Group = struct {
    vertices: std.AutoHashMapUnmanaged(Corner, u32) = .empty,
    positions: ArrayList(f32) = .empty,
    normals: ArrayList(f32) = .empty,
    uvs: ArrayList(f32) = .empty,
    indices: ArrayList(u32) = .empty,
};

const RawData = struct {
    positions: ArrayList([3]f32) = .empty,
    uvs: ArrayList([2]f32) = .empty,
    normals: ArrayList([3]f32) = .empty,
};

const ParsedObj = struct {
    groups: std.StringArrayHashMapUnmanaged(*Group) = .empty,
    material_libraries: ArrayList([]const u8) = .empty,
};

const Line = struct {
    keyword: []const u8,
    rest: []const u8,
};

pub fn load(io: Io, allocator: Allocator, path: []const u8) !Model {
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const temp = scratch.allocator();

    const folder = std.fs.path.dirname(path) orelse "";

    const source = try readAsset(io, temp, path);
    const parsed = try parseObj(temp, source);

    var materials: MaterialMap = .empty;
    for (parsed.material_libraries.items) |library| {
        const library_path = try std.fs.path.join(temp, &.{ folder, library });
        const library_source = try readAsset(io, temp, library_path);
        try parseMtl(temp, library_source, folder, &materials);
    }

    return buildModel(allocator, &parsed, &materials);
}

fn readAsset(io: Io, allocator: Allocator, path: []const u8) ![]u8 {
    const full_path = try std.fs.path.join(allocator, &.{ assets.root, path });
    defer allocator.free(full_path);

    return Io.Dir.readFileAlloc(
        Io.Dir.cwd(),
        io,
        full_path,
        allocator,
        .unlimited,
    );
}

pub fn parseObj(allocator: Allocator, source: []const u8) !ParsedObj {
    var parsed: ParsedObj = .{};
    var raw: RawData = .{};
    var corners: ArrayList(u32) = .empty;
    var group_name: []const u8 = "";

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |text| {
        const line = parseLine(text) orelse continue;

        if (std.mem.eql(u8, line.keyword, "v")) {
            try raw.positions.append(allocator, try parseFloats(3, line.rest));
        } else if (std.mem.eql(u8, line.keyword, "vt")) {
            const uv = try parseFloats(2, line.rest);
            try raw.uvs.append(allocator, .{ uv[0], 1.0 - uv[1] });
        } else if (std.mem.eql(u8, line.keyword, "vn")) {
            try raw.normals.append(allocator, try parseFloats(3, line.rest));
        } else if (std.mem.eql(u8, line.keyword, "usemtl")) {
            group_name = line.rest;
        } else if (std.mem.eql(u8, line.keyword, "mtllib")) {
            try parsed.material_libraries.append(allocator, line.rest);
        } else if (std.mem.eql(u8, line.keyword, "f")) {
            const entry = try parsed.groups.getOrPut(allocator, group_name);
            if (!entry.found_existing) {
                entry.value_ptr.* = try allocator.create(Group);
                entry.value_ptr.*.* = .{};
            }
            try addFace(allocator, entry.value_ptr.*, &raw, line.rest, &corners);
        }
    }

    return parsed;
}

fn addFace(
    allocator: Allocator,
    group: *Group,
    raw: *const RawData,
    face: []const u8,
    corners: *ArrayList(u32),
) !void {
    corners.clearRetainingCapacity();

    var tokens = std.mem.tokenizeAny(u8, face, " \t");
    while (tokens.next()) |token| {
        try corners.append(allocator, try addCorner(allocator, group, raw, token));
    }

    if (corners.items.len < 3) return error.InvalidFace;

    for (1..corners.items.len - 1) |i| {
        try group.indices.appendSlice(allocator, &.{
            corners.items[0],
            corners.items[i],
            corners.items[i + 1],
        });
    }
}

fn addCorner(
    allocator: Allocator,
    group: *Group,
    raw: *const RawData,
    token: []const u8,
) !u32 {
    var fields = std.mem.splitScalar(u8, token, '/');
    const corner: Corner = .{
        .v = try resolveIndex(fields.next(), raw.positions.items.len),
        .vt = try resolveIndex(fields.next(), raw.uvs.items.len),
        .vn = try resolveIndex(fields.next(), raw.normals.items.len),
    };

    if (corner.v == no_index) return error.InvalidFace;
    if (corner.vn == no_index) return error.MissingNormals;

    const entry = try group.vertices.getOrPut(allocator, corner);
    if (entry.found_existing) return entry.value_ptr.*;

    const index: u32 = @intCast(group.positions.items.len / 3);
    entry.value_ptr.* = index;

    const uv: [2]f32 = if (corner.vt == no_index) .{ 0, 0 } else raw.uvs.items[corner.vt];

    try group.positions.appendSlice(allocator, &raw.positions.items[corner.v]);
    try group.normals.appendSlice(allocator, &raw.normals.items[corner.vn]);
    try group.uvs.appendSlice(allocator, &uv);

    return index;
}

fn resolveIndex(field: ?[]const u8, len: usize) !u32 {
    const text = field orelse return no_index;
    if (text.len == 0) return no_index;

    const index = try std.fmt.parseInt(i64, text, 10);
    const resolved = if (index < 0) @as(i64, @intCast(len)) + index else index - 1;

    if (resolved < 0 or resolved >= len) return error.InvalidIndex;

    return @intCast(resolved);
}

pub fn parseMtl(
    allocator: Allocator,
    source: []const u8,
    folder: []const u8,
    materials: *MaterialMap,
) !void {
    var current: ?*MaterialInfo = null;

    var lines = std.mem.splitScalar(u8, source, '\n');
    while (lines.next()) |text| {
        const line = parseLine(text) orelse continue;

        if (std.mem.eql(u8, line.keyword, "newmtl")) {
            const entry = try materials.getOrPut(allocator, line.rest);
            entry.value_ptr.* = .{};
            current = entry.value_ptr;
            continue;
        }

        const material = current orelse continue;

        if (std.mem.eql(u8, line.keyword, "Kd")) {
            const colour = try parseFloats(3, line.rest);
            material.diffuse_colour = zalg.Vec3.new(colour[0], colour[1], colour[2]);
        } else if (std.mem.eql(u8, line.keyword, "map_Kd")) {
            const file = try normalisePath(allocator, line.rest);
            material.texture_path = try std.fs.path.join(allocator, &.{ folder, file });
        }
    }
}

pub fn buildModel(
    allocator: Allocator,
    parsed: *const ParsedObj,
    materials: *const MaterialMap,
) !Model {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const result = arena.allocator();

    const parts = try result.alloc(Part, parsed.groups.count());

    for (parsed.groups.keys(), parsed.groups.values(), parts) |name, group, *part| {
        const material = materials.get(name) orelse MaterialInfo{};

        part.* = .{
            .name = try result.dupe(u8, name),
            .data = .{
                .positions = try result.dupe(f32, group.positions.items),
                .indices = try result.dupe(u32, group.indices.items),
                .normals = try result.dupe(f32, group.normals.items),
                .uvs = try result.dupe(f32, group.uvs.items),
            },
            .diffuse_colour = material.diffuse_colour,
            .texture_path = if (material.texture_path) |path|
                try result.dupe(u8, path)
            else
                null,
        };
    }

    return .{
        .arena = arena,
        .parts = parts,
    };
}

fn parseLine(text: []const u8) ?Line {
    const line = std.mem.trim(u8, text, " \t\r");
    if (line.len == 0 or line[0] == '#') return null;

    const end = std.mem.indexOfAny(u8, line, " \t") orelse line.len;

    return .{
        .keyword = line[0..end],
        .rest = std.mem.trim(u8, line[end..], " \t"),
    };
}

fn parseFloats(comptime count: usize, text: []const u8) ![count]f32 {
    var values: [count]f32 = undefined;

    var tokens = std.mem.tokenizeAny(u8, text, " \t");
    for (&values) |*value| {
        const token = tokens.next() orelse return error.MissingValue;
        value.* = try std.fmt.parseFloat(f32, token);
    }

    return values;
}

fn normalisePath(allocator: Allocator, path: []const u8) ![]u8 {
    var result: ArrayList(u8) = .empty;

    for (path) |char| {
        if (char != '\\') {
            try result.append(allocator, char);
        } else if (result.getLastOrNull() != '/') {
            try result.append(allocator, '/');
        }
    }

    return result.items;
}
