const std = @import("std");
const zalg = @import("zalgebra");
const assets = @import("../assets.zig");
const MeshData = @import("MeshData.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Part = struct {
    name: []const u8,
    mesh: usize,
    data: MeshData,
    diffuse_colour: zalg.Vec3,
};

pub const ModelNode = struct {
    name: []const u8,
    parent: ?usize,
    children: []const usize,
    mesh: ?usize,
    skin: ?usize,
    translation: zalg.Vec3,
    rotation: zalg.Quat,
    scale: zalg.Vec3,
    matrix: ?zalg.Mat4,
};

pub const ModelSkin = struct {
    name: []const u8,
    joints: []const usize,
    inverse_bind_matrices: []zalg.Mat4,
};

pub const Track = struct {
    node: usize,
    path: Path,
    interpolation: Interpolation,
    times: []f32,
    // 3 floats per key for translation and scale, 4 for rotation (x, y, z, w)
    values: []f32,
};

pub const Clip = struct {
    name: []const u8,
    duration: f32,
    tracks: []Track,
};

pub const Model = struct {
    arena: std.heap.ArenaAllocator,
    parts: []Part,
    nodes: []ModelNode,
    node_order: []usize,
    skins: []ModelSkin,
    clips: []Clip,

    pub fn deinit(self: *Model) void {
        self.arena.deinit();
    }
};

// Field names mirror glTF JSON keys so std.json can fill them directly

pub const ComponentType = enum(u32) {
    byte = 5120,
    unsigned_byte = 5121,
    short = 5122,
    unsigned_short = 5123,
    unsigned_int = 5125,
    float = 5126,

    pub fn size(self: ComponentType) usize {
        return switch (self) {
            .byte, .unsigned_byte => 1,
            .short, .unsigned_short => 2,
            .unsigned_int, .float => 4,
        };
    }
};

pub const AccessorType = enum {
    SCALAR,
    VEC2,
    VEC3,
    VEC4,
    MAT2,
    MAT3,
    MAT4,

    pub fn components(self: AccessorType) usize {
        return switch (self) {
            .SCALAR => 1,
            .VEC2 => 2,
            .VEC3 => 3,
            .VEC4, .MAT2 => 4,
            .MAT3 => 9,
            .MAT4 => 16,
        };
    }
};

pub const Scene = struct {
    nodes: []const usize = &.{},
};

pub const Node = struct {
    name: ?[]const u8 = null,
    children: []const usize = &.{},
    translation: [3]f32 = .{ 0, 0, 0 },
    rotation: [4]f32 = .{ 0, 0, 0, 1 },
    scale: [3]f32 = .{ 1, 1, 1 },
    matrix: ?[16]f32 = null,
    mesh: ?usize = null,
    skin: ?usize = null,
};

pub const Attributes = struct {
    POSITION: usize,
    NORMAL: ?usize = null,
    TEXCOORD_0: ?usize = null,
    JOINTS_0: ?usize = null,
    WEIGHTS_0: ?usize = null,
};

pub const Primitive = struct {
    attributes: Attributes,
    indices: ?usize = null,
    material: ?usize = null,
    mode: u32 = 4,
};

pub const Mesh = struct {
    name: ?[]const u8 = null,
    primitives: []const Primitive,
};

pub const Material = struct {
    name: ?[]const u8 = null,
    pbrMetallicRoughness: struct {
        baseColorFactor: [4]f32 = .{ 1, 1, 1, 1 },
    } = .{},
};

pub const Skin = struct {
    name: ?[]const u8 = null,
    joints: []const usize,
    inverseBindMatrices: ?usize = null,
    skeleton: ?usize = null,
};

pub const Path = enum { translation, rotation, scale, weights };

pub const Interpolation = enum { LINEAR, STEP, CUBICSPLINE };

pub const Target = struct {
    node: ?usize = null,
    path: Path,
};

pub const Channel = struct {
    sampler: usize,
    target: Target,
};

pub const Sampler = struct {
    input: usize,
    output: usize,
    interpolation: Interpolation = .LINEAR,
};

pub const Animation = struct {
    name: ?[]const u8 = null,
    channels: []const Channel,
    samplers: []const Sampler,
};

pub const Accessor = struct {
    bufferView: ?usize = null,
    byteOffset: usize = 0,
    componentType: ComponentType,
    normalized: bool = false,
    count: usize,
    type: AccessorType,
    sparse: ?std.json.Value = null,
};

pub const BufferView = struct {
    buffer: usize,
    byteOffset: usize = 0,
    byteLength: usize,
    byteStride: ?usize = null,
};

pub const Buffer = struct {
    uri: ?[]const u8 = null,
    byteLength: usize,
};

pub const Document = struct {
    scene: ?usize = null,
    scenes: []const Scene = &.{},
    nodes: []const Node = &.{},
    meshes: []const Mesh = &.{},
    materials: []const Material = &.{},
    skins: []const Skin = &.{},
    animations: []const Animation = &.{},
    accessors: []const Accessor = &.{},
    bufferViews: []const BufferView = &.{},
    buffers: []const Buffer = &.{},
};

pub fn load(io: Io, allocator: Allocator, path: []const u8) !Model {
    var scratch = std.heap.ArenaAllocator.init(allocator);
    defer scratch.deinit();
    const temp = scratch.allocator();

    const folder = std.fs.path.dirname(path) orelse "";

    const source = try readAsset(io, temp, path);
    const glb: ?Glb = if (std.mem.startsWith(u8, source, "glTF")) try parseGlb(source) else null;
    const document = try parseDocument(temp, if (glb) |file| file.json else source);

    const buffers = try temp.alloc([]const u8, document.buffers.len);
    for (document.buffers, buffers, 0..) |buffer, *bytes, index| {
        if (buffer.uri) |uri| {
            if (std.mem.startsWith(u8, uri, "data:")) return error.UnsupportedBuffer;

            const buffer_path = try std.fs.path.join(temp, &.{ folder, uri });
            bytes.* = try readAsset(io, temp, buffer_path);
        } else {
            // in a glb only the first buffer can have no uri, it is the bin chunk
            const bin = if (glb) |file| file.bin else null;
            if (index != 0) return error.UnsupportedBuffer;
            bytes.* = bin orelse return error.UnsupportedBuffer;
        }

        if (bytes.len < buffer.byteLength) return error.BufferTooShort;
    }

    return buildModel(allocator, &document, buffers);
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

pub const Glb = struct {
    json: []const u8,
    bin: ?[]const u8,
};

const Chunk = struct {
    kind: u32,
    data: []const u8,
    end: usize,
};

const glb_magic: u32 = 0x46546C67; // "glTF"
const json_chunk: u32 = 0x4E4F534A; // "JSON"
const bin_chunk: u32 = 0x004E4942; // "BIN\0"

// 12 byte header then a json chunk and an optional bin chunk
pub fn parseGlb(bytes: []const u8) !Glb {
    if (bytes.len < 12) return error.InvalidGlb;
    if (readU32(bytes[0..]) != glb_magic) return error.InvalidGlb;
    if (readU32(bytes[4..]) != 2) return error.UnsupportedGlbVersion;

    const length = readU32(bytes[8..]);
    if (length < 12 or length > bytes.len) return error.InvalidGlb;
    const file = bytes[0..length];

    const json = try readChunk(file, 12);
    if (json.kind != json_chunk) return error.InvalidGlb;

    var bin: ?[]const u8 = null;
    if (json.end < file.len) {
        const chunk = try readChunk(file, json.end);
        if (chunk.kind == bin_chunk) bin = chunk.data;
    }

    return .{ .json = json.data, .bin = bin };
}

fn readChunk(bytes: []const u8, offset: usize) !Chunk {
    if (bytes.len - offset < 8) return error.InvalidGlb;

    const length = readU32(bytes[offset..]);
    const start = offset + 8;
    if (length > bytes.len - start) return error.InvalidGlb;

    return .{
        .kind = readU32(bytes[offset + 4 ..]),
        .data = bytes[start..][0..length],
        .end = start + length,
    };
}

fn readU32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .little);
}

pub fn parseDocument(allocator: Allocator, source: []const u8) !Document {
    return std.json.parseFromSliceLeaky(Document, allocator, source, .{
        .ignore_unknown_fields = true,
    });
}

pub fn buildModel(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
) !Model {
    var arena = std.heap.ArenaAllocator.init(allocator);
    errdefer arena.deinit();
    const result = arena.allocator();

    var parts: ArrayList(Part) = .empty;

    for (document.meshes, 0..) |mesh, mesh_index| {
        for (mesh.primitives) |primitive| {
            try parts.append(result, .{
                .name = try result.dupe(u8, mesh.name orelse ""),
                .mesh = mesh_index,
                .data = try readPrimitive(result, document, buffers, primitive),
                .diffuse_colour = try diffuseColour(document, primitive.material),
            });
        }
    }

    const nodes = try readNodes(result, document);

    return .{
        .arena = arena,
        .parts = parts.items,
        .nodes = nodes,
        .node_order = try orderNodes(result, nodes),
        .skins = try readSkins(result, document, buffers),
        .clips = try readClips(result, document, buffers),
    };
}

pub fn readAccessor(
    comptime T: type,
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
    index: usize,
) ![]T {
    if (index >= document.accessors.len) return error.InvalidIndex;
    const accessor = document.accessors[index];
    if (accessor.sparse != null) return error.UnsupportedSparseAccessor;

    const view_index = accessor.bufferView orelse return error.MissingBufferView;
    if (view_index >= document.bufferViews.len) return error.InvalidIndex;
    const view = document.bufferViews[view_index];

    if (view.buffer >= buffers.len) return error.InvalidIndex;
    const buffer = buffers[view.buffer];
    if (view.byteOffset + view.byteLength > buffer.len) return error.AccessorOutOfBounds;
    const bytes = buffer[view.byteOffset..][0..view.byteLength];

    const component_size = accessor.componentType.size();
    const components = accessor.type.components();
    const element_size = component_size * components;
    const stride = view.byteStride orelse element_size;

    if (accessor.count > 0) {
        const end = accessor.byteOffset + (accessor.count - 1) * stride + element_size;
        if (end > bytes.len) return error.AccessorOutOfBounds;
    }

    const values = try allocator.alloc(T, accessor.count * components);
    errdefer allocator.free(values);

    for (0..accessor.count) |i| {
        const element = bytes[accessor.byteOffset + i * stride ..];
        for (0..components) |j| {
            values[i * components + j] = try readComponent(
                T,
                element[j * component_size ..],
                accessor,
            );
        }
    }

    return values;
}

fn readPrimitive(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
    primitive: Primitive,
) !MeshData {
    if (primitive.mode != 4) return error.UnsupportedPrimitiveMode;

    const attributes = primitive.attributes;
    if ((attributes.JOINTS_0 == null) != (attributes.WEIGHTS_0 == null)) {
        return error.IncompleteSkinAttributes;
    }

    if (attributes.POSITION >= document.accessors.len) return error.InvalidIndex;
    const vertex_count = document.accessors[attributes.POSITION].count;

    return .{
        .positions = try readAttribute(f32, allocator, document, buffers, attributes.POSITION, .VEC3, vertex_count),
        .indices = try readIndices(allocator, document, buffers, primitive.indices, vertex_count),
        .normals = if (attributes.NORMAL) |index|
            try readAttribute(f32, allocator, document, buffers, index, .VEC3, vertex_count)
        else
            null,
        .uvs = if (attributes.TEXCOORD_0) |index|
            try readAttribute(f32, allocator, document, buffers, index, .VEC2, vertex_count)
        else
            null,
        .joints = if (attributes.JOINTS_0) |index|
            try readAttribute(u16, allocator, document, buffers, index, .VEC4, vertex_count)
        else
            null,
        .weights = if (attributes.WEIGHTS_0) |index|
            try readAttribute(f32, allocator, document, buffers, index, .VEC4, vertex_count)
        else
            null,
    };
}

fn readAttribute(
    comptime T: type,
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
    index: usize,
    expected: AccessorType,
    vertex_count: usize,
) ![]T {
    const values = try readAccessor(T, allocator, document, buffers, index);

    const accessor = document.accessors[index];
    if (accessor.type != expected) return error.UnexpectedAccessorType;
    if (accessor.count != vertex_count) return error.AttributeCountMismatch;

    return values;
}

fn readIndices(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
    index: ?usize,
    vertex_count: usize,
) ![]u32 {
    const accessor_index = index orelse {
        const indices = try allocator.alloc(u32, vertex_count);
        for (indices, 0..) |*value, i| value.* = @intCast(i);
        return indices;
    };

    const indices = try readAccessor(u32, allocator, document, buffers, accessor_index);
    if (document.accessors[accessor_index].type != .SCALAR) return error.UnexpectedAccessorType;
    if (indices.len % 3 != 0) return error.InvalidTriangles;

    for (indices) |value| {
        if (value >= vertex_count) return error.InvalidIndex;
    }

    return indices;
}

fn diffuseColour(document: *const Document, material: ?usize) !zalg.Vec3 {
    const index = material orelse return zalg.Vec3.new(1, 1, 1);
    if (index >= document.materials.len) return error.InvalidIndex;

    const colour = document.materials[index].pbrMetallicRoughness.baseColorFactor;
    return zalg.Vec3.new(colour[0], colour[1], colour[2]);
}

fn readNodes(allocator: Allocator, document: *const Document) ![]ModelNode {
    const nodes = try allocator.alloc(ModelNode, document.nodes.len);

    for (document.nodes, nodes) |node, *result| {
        if (node.mesh) |mesh| if (mesh >= document.meshes.len) return error.InvalidIndex;
        if (node.skin) |skin| if (skin >= document.skins.len) return error.InvalidIndex;

        result.* = .{
            .name = try allocator.dupe(u8, node.name orelse ""),
            .parent = null,
            .children = try allocator.dupe(usize, node.children),
            .mesh = node.mesh,
            .skin = node.skin,
            .translation = zalg.Vec3.new(node.translation[0], node.translation[1], node.translation[2]),
            .rotation = zalg.Quat.fromSlice(&node.rotation),
            .scale = zalg.Vec3.new(node.scale[0], node.scale[1], node.scale[2]),
            .matrix = if (node.matrix) |matrix| zalg.Mat4.fromSlice(&matrix) else null,
        };
    }

    for (nodes, 0..) |node, parent| {
        for (node.children) |child| {
            if (child >= nodes.len) return error.InvalidIndex;
            if (nodes[child].parent != null) return error.MultipleParents;
            nodes[child].parent = parent;
        }
    }

    return nodes;
}

fn orderNodes(allocator: Allocator, nodes: []const ModelNode) ![]usize {
    var order: ArrayList(usize) = .empty;

    for (nodes, 0..) |node, index| {
        if (node.parent == null) try order.append(allocator, index);
    }

    var next: usize = 0;
    while (next < order.items.len) : (next += 1) {
        try order.appendSlice(allocator, nodes[order.items[next]].children);
    }

    if (order.items.len != nodes.len) return error.NodeCycle;

    return order.items;
}

fn readSkins(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
) ![]ModelSkin {
    const skins = try allocator.alloc(ModelSkin, document.skins.len);

    for (document.skins, skins) |skin, *result| {
        for (skin.joints) |joint| {
            if (joint >= document.nodes.len) return error.InvalidIndex;
        }

        const matrices = try allocator.alloc(zalg.Mat4, skin.joints.len);

        if (skin.inverseBindMatrices) |index| {
            const values = try readAttribute(f32, allocator, document, buffers, index, .MAT4, skin.joints.len);
            for (matrices, 0..) |*matrix, i| {
                matrix.* = zalg.Mat4.fromSlice(values[i * 16 ..][0..16]);
            }
        } else {
            @memset(matrices, zalg.Mat4.identity());
        }

        result.* = .{
            .name = try allocator.dupe(u8, skin.name orelse ""),
            .joints = try allocator.dupe(usize, skin.joints),
            .inverse_bind_matrices = matrices,
        };
    }

    return skins;
}

fn readClips(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
) ![]Clip {
    const clips = try allocator.alloc(Clip, document.animations.len);

    for (document.animations, clips) |animation, *clip| {
        var tracks: ArrayList(Track) = .empty;
        var duration: f32 = 0;

        for (animation.channels) |channel| {
            if (channel.target.path == .weights) continue;
            const node = channel.target.node orelse continue;

            if (node >= document.nodes.len) return error.InvalidIndex;
            if (channel.sampler >= animation.samplers.len) return error.InvalidIndex;

            const track = try readTrack(
                allocator,
                document,
                buffers,
                node,
                channel.target.path,
                animation.samplers[channel.sampler],
            );
            duration = @max(duration, track.times[track.times.len - 1]);
            try tracks.append(allocator, track);
        }

        clip.* = .{
            .name = try allocator.dupe(u8, animation.name orelse ""),
            .duration = duration,
            .tracks = tracks.items,
        };
    }

    return clips;
}

fn readTrack(
    allocator: Allocator,
    document: *const Document,
    buffers: []const []const u8,
    node: usize,
    path: Path,
    sampler: Sampler,
) !Track {
    const times = try readAccessor(f32, allocator, document, buffers, sampler.input);
    if (document.accessors[sampler.input].type != .SCALAR) return error.UnexpectedAccessorType;
    if (times.len == 0) return error.EmptyTrack;

    const key_count = if (sampler.interpolation == .CUBICSPLINE) times.len * 3 else times.len;
    const value_type: AccessorType = if (path == .rotation) .VEC4 else .VEC3;

    return .{
        .node = node,
        .path = path,
        .interpolation = sampler.interpolation,
        .times = times,
        .values = try readAttribute(f32, allocator, document, buffers, sampler.output, value_type, key_count),
    };
}

fn readComponent(comptime T: type, bytes: []const u8, accessor: Accessor) !T {
    const normalized = accessor.normalized;

    return switch (accessor.componentType) {
        .float => readFloat(T, bytes),
        .byte => convert(T, @as(i8, @bitCast(bytes[0])), normalized),
        .unsigned_byte => convert(T, bytes[0], normalized),
        .short => convert(T, std.mem.readInt(i16, bytes[0..2], .little), normalized),
        .unsigned_short => convert(T, std.mem.readInt(u16, bytes[0..2], .little), normalized),
        .unsigned_int => convert(T, std.mem.readInt(u32, bytes[0..4], .little), normalized),
    };
}

fn readFloat(comptime T: type, bytes: []const u8) !T {
    if (T != f32) return error.ComponentTypeMismatch;
    return @bitCast(std.mem.readInt(u32, bytes[0..4], .little));
}

fn convert(comptime T: type, value: anytype, normalized: bool) !T {
    if (T == f32) {
        if (!normalized) return error.ComponentTypeMismatch;
        const max: f32 = @floatFromInt(std.math.maxInt(@TypeOf(value)));
        return @max(@as(f32, @floatFromInt(value)) / max, -1.0);
    }

    return std.math.cast(T, value) orelse error.ComponentOutOfRange;
}
