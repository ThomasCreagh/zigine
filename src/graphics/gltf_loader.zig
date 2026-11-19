const std = @import("std");
const zalg = @import("zalgebra");
const MeshData = @import("MeshData.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Part = struct {
    name: []const u8,
    mesh: usize,
    data: MeshData,
    diffuse_colour: zalg.Vec3,
};

pub const Model = struct {
    arena: std.heap.ArenaAllocator,
    parts: []Part,

    pub fn deinit(self: *Model) void {
        self.arena.deinit();
    }
};

// Field names below mirror the glTF JSON keys so std.json can fill them directly.

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

pub const Target = struct {
    node: ?usize = null,
    path: enum { translation, rotation, scale, weights },
};

pub const Channel = struct {
    sampler: usize,
    target: Target,
};

pub const Sampler = struct {
    input: usize,
    output: usize,
    interpolation: enum { LINEAR, STEP, CUBICSPLINE } = .LINEAR,
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

/// Strings in the result may point into `source`, so keep it alive as long as the document.
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

    return .{
        .arena = arena,
        .parts = parts.items,
    };
}

/// Reads every component of an accessor into a flat slice, e.g. a VEC3 accessor
/// with 10 elements gives 30 values.
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
    // Primitives without indices draw their vertices in order
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
