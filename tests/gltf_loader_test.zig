const std = @import("std");
const gltf_loader = @import("zigine").gltf_loader;

const testing = std.testing;

fn parse(arena: *std.heap.ArenaAllocator, json: []const u8) !gltf_loader.Document {
    return gltf_loader.parseDocument(arena.allocator(), json);
}

fn document(arena: *std.heap.ArenaAllocator, accessors: []const u8, views: []const u8) !gltf_loader.Document {
    const json = try std.fmt.allocPrint(
        arena.allocator(),
        "{{\"accessors\":[{s}],\"bufferViews\":[{s}],\"buffers\":[{{\"byteLength\":0}}]}}",
        .{ accessors, views },
    );
    return parse(arena, json);
}

test "node defaults" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const doc = try parse(&arena,
        \\{"asset":{"version":"2.0"},"nodes":[{"name":"Hips","extras":{}}]}
    );
    const node = doc.nodes[0];

    try testing.expectEqualStrings("Hips", node.name.?);
    try testing.expectEqual(0, node.children.len);
    try testing.expectEqual([3]f32{ 0, 0, 0 }, node.translation);
    try testing.expectEqual([4]f32{ 0, 0, 0, 1 }, node.rotation);
    try testing.expectEqual([3]f32{ 1, 1, 1 }, node.scale);
    try testing.expectEqual(null, node.matrix);
}

test "animation enums" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const doc = try parse(&arena,
        \\{"animations":[{
        \\  "channels":[{"sampler":0,"target":{"node":2,"path":"rotation"}}],
        \\  "samplers":[{"input":0,"output":1},{"input":0,"output":1,"interpolation":"STEP"}]
        \\}]}
    );
    const animation = doc.animations[0];

    try testing.expectEqual(.rotation, animation.channels[0].target.path);
    try testing.expectEqual(.LINEAR, animation.samplers[0].interpolation);
    try testing.expectEqual(.STEP, animation.samplers[1].interpolation);
}

test "float vec3" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const doc = try document(
        &arena,
        \\{"bufferView":0,"componentType":5126,"count":2,"type":"VEC3"}
    ,
        \\{"buffer":0,"byteLength":24}
    );
    const data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    const values = try gltf_loader.readAccessor(f32, arena.allocator(), &doc, &.{std.mem.sliceAsBytes(&data)}, 0);

    try testing.expectEqualSlices(f32, &data, values);
}

test "u16 indices widen to u32" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const doc = try document(
        &arena,
        \\{"bufferView":0,"componentType":5123,"count":3,"type":"SCALAR"}
    ,
        \\{"buffer":0,"byteLength":6}
    );
    const data = [_]u16{ 0, 1, 65535 };
    const values = try gltf_loader.readAccessor(u32, arena.allocator(), &doc, &.{std.mem.sliceAsBytes(&data)}, 0);

    try testing.expectEqualSlices(u32, &.{ 0, 1, 65535 }, values);
}

test "offsets and stride" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    // Two interleaved vertices of position (2 floats) and colour (1 float), after 1 float of padding
    const doc = try document(
        &arena,
        \\{"bufferView":0,"byteOffset":8,"componentType":5126,"count":2,"type":"SCALAR"}
    ,
        \\{"buffer":0,"byteOffset":4,"byteLength":24,"byteStride":12}
    );
    const data = [_]f32{ 0, 1, 2, 10, 3, 4, 20 };
    const values = try gltf_loader.readAccessor(f32, arena.allocator(), &doc, &.{std.mem.sliceAsBytes(&data)}, 0);

    try testing.expectEqualSlices(f32, &.{ 10, 20 }, values);
}

test "normalized u8" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const doc = try document(
        &arena,
        \\{"bufferView":0,"componentType":5121,"normalized":true,"count":2,"type":"SCALAR"}
    ,
        \\{"buffer":0,"byteLength":2}
    );
    const data = [_]u8{ 0, 255 };
    const values = try gltf_loader.readAccessor(f32, arena.allocator(), &doc, &.{&data}, 0);

    try testing.expectEqualSlices(f32, &.{ 0, 1 }, values);
}

test "bad accessors" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const doc = try document(
        &arena,
        \\{"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"},
        \\{"bufferView":0,"componentType":5126,"count":1,"type":"SCALAR"},
        \\{"bufferView":0,"componentType":5121,"count":1,"type":"SCALAR"},
        \\{"bufferView":0,"componentType":5126,"count":1,"type":"SCALAR","sparse":{}},
        \\{"componentType":5126,"count":1,"type":"SCALAR"}
    ,
        \\{"buffer":0,"byteLength":24}
    );
    const data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    const buffers: []const []const u8 = &.{std.mem.sliceAsBytes(&data)};

    try testing.expectError(error.AccessorOutOfBounds, gltf_loader.readAccessor(f32, allocator, &doc, buffers, 0));
    try testing.expectError(error.ComponentTypeMismatch, gltf_loader.readAccessor(u32, allocator, &doc, buffers, 1));
    try testing.expectError(error.ComponentTypeMismatch, gltf_loader.readAccessor(f32, allocator, &doc, buffers, 2));
    try testing.expectError(error.UnsupportedSparseAccessor, gltf_loader.readAccessor(f32, allocator, &doc, buffers, 3));
    try testing.expectError(error.MissingBufferView, gltf_loader.readAccessor(f32, allocator, &doc, buffers, 4));
    try testing.expectError(error.InvalidIndex, gltf_loader.readAccessor(f32, allocator, &doc, buffers, 5));
}
