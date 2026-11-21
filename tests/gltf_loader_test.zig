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

    const doc = try document(&arena,
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

    const doc = try document(&arena,
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

    const doc = try document(&arena,
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

    const doc = try document(&arena,
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

    const doc = try document(&arena,
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

const mesh_positions = [_]f32{ 0, 0, 0, 1, 0, 0, 0, 1, 0 };
const mesh_normals = [_]f32{ 0, 0, 1, 0, 0, 1, 0, 0, 1 };
const mesh_indices = [_]u16{ 0, 1, 2 };
const mesh_joints = [_]u8{ 0, 1, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0 };
const mesh_weights = [_]f32{ 0.5, 0.5, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 };
const bad_indices = [_]u16{ 0, 1, 5 };

const mesh_document =
    \\"accessors":[
    \\  {"bufferView":0,"componentType":5126,"count":3,"type":"VEC3"},
    \\  {"bufferView":1,"componentType":5126,"count":3,"type":"VEC3"},
    \\  {"bufferView":2,"componentType":5123,"count":3,"type":"SCALAR"},
    \\  {"bufferView":3,"componentType":5121,"count":3,"type":"VEC4"},
    \\  {"bufferView":4,"componentType":5126,"count":3,"type":"VEC4"},
    \\  {"bufferView":1,"componentType":5126,"count":2,"type":"VEC3"},
    \\  {"bufferView":0,"componentType":5126,"count":3,"type":"VEC2"},
    \\  {"bufferView":5,"componentType":5123,"count":3,"type":"SCALAR"}
    \\],
    \\"bufferViews":[
    \\  {"buffer":0,"byteLength":36},
    \\  {"buffer":1,"byteLength":36},
    \\  {"buffer":2,"byteLength":6},
    \\  {"buffer":3,"byteLength":12},
    \\  {"buffer":4,"byteLength":48},
    \\  {"buffer":5,"byteLength":6}
    \\],
    \\"materials":[{"pbrMetallicRoughness":{"baseColorFactor":[0.5,0.25,1,1]}}]
;

fn meshModel(meshes: []const u8) !gltf_loader.Model {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const json = try std.mem.concat(arena.allocator(), u8, &.{ "{", mesh_document, ",\"meshes\":[", meshes, "]}" });
    const doc = try parse(&arena, json);
    const buffers: []const []const u8 = &.{
        std.mem.sliceAsBytes(&mesh_positions),
        std.mem.sliceAsBytes(&mesh_normals),
        std.mem.sliceAsBytes(&mesh_indices),
        &mesh_joints,
        std.mem.sliceAsBytes(&mesh_weights),
        std.mem.sliceAsBytes(&bad_indices),
    };

    return gltf_loader.buildModel(testing.allocator, &doc, buffers);
}

test "triangle primitive" {
    var model = try meshModel(
        \\{"name":"tri","primitives":[{"attributes":{"POSITION":0,"NORMAL":1},"indices":2,"material":0}]}
    );
    defer model.deinit();
    const part = model.parts[0];

    try testing.expectEqual(1, model.parts.len);
    try testing.expectEqualStrings("tri", part.name);
    try testing.expectEqualSlices(f32, &mesh_positions, part.data.positions);
    try testing.expectEqualSlices(f32, &mesh_normals, part.data.normals.?);
    try testing.expectEqualSlices(u32, &.{ 0, 1, 2 }, part.data.indices);
    try testing.expectEqual(null, part.data.uvs);
    try testing.expectEqual(null, part.data.joints);
    try testing.expectEqual(0.5, part.diffuse_colour.data[0]);
    try testing.expectEqual(0.25, part.diffuse_colour.data[1]);
}

test "generated indices and default colour" {
    var model = try meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0}}]}
    );
    defer model.deinit();
    const part = model.parts[0];

    try testing.expectEqualStrings("", part.name);
    try testing.expectEqualSlices(u32, &.{ 0, 1, 2 }, part.data.indices);
    try testing.expectEqual(1.0, part.diffuse_colour.data[0]);
}

test "skin attributes" {
    var model = try meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0,"JOINTS_0":3,"WEIGHTS_0":4}}]}
    );
    defer model.deinit();
    const part = model.parts[0];

    try testing.expectEqualSlices(u16, &.{ 0, 1, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0 }, part.data.joints.?);
    try testing.expectEqualSlices(f32, &mesh_weights, part.data.weights.?);
}

test "one part per primitive" {
    var model = try meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0}},{"attributes":{"POSITION":0}}]},
        \\{"primitives":[{"attributes":{"POSITION":0}}]}
    );
    defer model.deinit();

    try testing.expectEqual(3, model.parts.len);
    try testing.expectEqual(0, model.parts[1].mesh);
    try testing.expectEqual(1, model.parts[2].mesh);
}

test "bad primitives" {
    try testing.expectError(error.UnsupportedPrimitiveMode, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0},"mode":1}]}
    ));
    try testing.expectError(error.IncompleteSkinAttributes, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0,"JOINTS_0":3}}]}
    ));
    try testing.expectError(error.AttributeCountMismatch, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0,"NORMAL":5}}]}
    ));
    try testing.expectError(error.UnexpectedAccessorType, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":6}}]}
    ));
    try testing.expectError(error.InvalidIndex, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0},"indices":7}]}
    ));
    try testing.expectError(error.InvalidIndex, meshModel(
        \\{"primitives":[{"attributes":{"POSITION":0},"material":3}]}
    ));
}

const key_times = [_]f32{ 0, 1, 2 };
const key_translations = [_]f32{ 0, 0, 0, 1, 0, 0, 2, 0, 0 };
const key_rotations = [_]f32{ 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1 };
const bind_matrices = blk: {
    var values: [32]f32 = undefined;
    for (&values, 0..) |*value, i| value.* = @floatFromInt(i);
    break :blk values;
};

const skeleton_document =
    \\"accessors":[
    \\  {"bufferView":0,"componentType":5126,"count":3,"type":"SCALAR"},
    \\  {"bufferView":1,"componentType":5126,"count":3,"type":"VEC3"},
    \\  {"bufferView":2,"componentType":5126,"count":3,"type":"VEC4"},
    \\  {"bufferView":3,"componentType":5126,"count":2,"type":"MAT4"},
    \\  {"bufferView":1,"componentType":5126,"count":2,"type":"VEC3"}
    \\],
    \\"bufferViews":[
    \\  {"buffer":0,"byteLength":12},
    \\  {"buffer":1,"byteLength":36},
    \\  {"buffer":2,"byteLength":48},
    \\  {"buffer":3,"byteLength":128}
    \\]
;

fn skeletonModel(extra: []const u8) !gltf_loader.Model {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const json = try std.mem.concat(arena.allocator(), u8, &.{ "{", skeleton_document, ",", extra, "}" });
    const doc = try parse(&arena, json);
    const buffers: []const []const u8 = &.{
        std.mem.sliceAsBytes(&key_times),
        std.mem.sliceAsBytes(&key_translations),
        std.mem.sliceAsBytes(&key_rotations),
        std.mem.sliceAsBytes(&bind_matrices),
    };

    return gltf_loader.buildModel(testing.allocator, &doc, buffers);
}

test "node hierarchy" {
    var model = try skeletonModel(
        \\"nodes":[
        \\  {"name":"Spine","children":[2]},
        \\  {"name":"Root","children":[0],"translation":[1,2,3]},
        \\  {"name":"Head","rotation":[0,0,1,0]},
        \\  {"name":"Prop"}
        \\]
    );
    defer model.deinit();
    const nodes = model.nodes;

    try testing.expectEqual(1, nodes[0].parent);
    try testing.expectEqual(null, nodes[1].parent);
    try testing.expectEqual(0, nodes[2].parent);
    try testing.expectEqualSlices(usize, &.{ 1, 3, 0, 2 }, model.node_order);
    try testing.expectEqual(1.0, nodes[1].translation.data[0]);
    try testing.expectEqual(1.0, nodes[2].rotation.z);
    try testing.expectEqual(0.0, nodes[2].rotation.w);
    try testing.expectEqual(1.0, nodes[3].scale.data[0]);
}

test "bad nodes" {
    try testing.expectError(error.MultipleParents, skeletonModel(
        \\"nodes":[{"children":[2]},{"children":[2]},{}]
    ));
    try testing.expectError(error.NodeCycle, skeletonModel(
        \\"nodes":[{"children":[1]},{"children":[0]}]
    ));
    try testing.expectError(error.InvalidIndex, skeletonModel(
        \\"nodes":[{"children":[5]}]
    ));
    try testing.expectError(error.InvalidIndex, skeletonModel(
        \\"nodes":[{"skin":0}]
    ));
}

test "skins" {
    var model = try skeletonModel(
        \\"nodes":[{},{}],
        \\"skins":[{"joints":[0,1],"inverseBindMatrices":3},{"joints":[1]}]
    );
    defer model.deinit();
    const matrices = model.skins[0].inverse_bind_matrices;

    try testing.expectEqualSlices(usize, &.{ 0, 1 }, model.skins[0].joints);
    try testing.expectEqual(12.0, matrices[0].data[3][0]);
    try testing.expectEqual(16.0, matrices[1].data[0][0]);
    try testing.expectEqual(1.0, model.skins[1].inverse_bind_matrices[0].data[0][0]);
    try testing.expectEqual(0.0, model.skins[1].inverse_bind_matrices[0].data[3][0]);
}

test "animation clip" {
    var model = try skeletonModel(
        \\"nodes":[{},{}],
        \\"animations":[{
        \\  "name":"walk",
        \\  "channels":[
        \\    {"sampler":0,"target":{"node":0,"path":"translation"}},
        \\    {"sampler":1,"target":{"node":1,"path":"rotation"}},
        \\    {"sampler":0,"target":{"node":0,"path":"weights"}},
        \\    {"sampler":0,"target":{"path":"scale"}}
        \\  ],
        \\  "samplers":[{"input":0,"output":1},{"input":0,"output":2,"interpolation":"STEP"}]
        \\}]
    );
    defer model.deinit();
    const clip = model.clips[0];

    try testing.expectEqualStrings("walk", clip.name);
    try testing.expectEqual(2.0, clip.duration);
    try testing.expectEqual(2, clip.tracks.len);
    try testing.expectEqualSlices(f32, &key_times, clip.tracks[0].times);
    try testing.expectEqualSlices(f32, &key_translations, clip.tracks[0].values);
    try testing.expectEqual(.rotation, clip.tracks[1].path);
    try testing.expectEqual(.STEP, clip.tracks[1].interpolation);
    try testing.expectEqual(1, clip.tracks[1].node);
}

test "bad animations" {
    try testing.expectError(error.UnexpectedAccessorType, skeletonModel(
        \\"nodes":[{}],
        \\"animations":[{"channels":[{"sampler":0,"target":{"node":0,"path":"rotation"}}],"samplers":[{"input":0,"output":1}]}]
    ));
    try testing.expectError(error.AttributeCountMismatch, skeletonModel(
        \\"nodes":[{}],
        \\"animations":[{"channels":[{"sampler":0,"target":{"node":0,"path":"scale"}}],"samplers":[{"input":0,"output":4}]}]
    ));
    try testing.expectError(error.AttributeCountMismatch, skeletonModel(
        \\"nodes":[{}],
        \\"animations":[{"channels":[{"sampler":0,"target":{"node":0,"path":"scale"}}],"samplers":[{"input":0,"output":1,"interpolation":"CUBICSPLINE"}]}]
    ));
    try testing.expectError(error.InvalidIndex, skeletonModel(
        \\"nodes":[{}],
        \\"animations":[{"channels":[{"sampler":5,"target":{"node":0,"path":"scale"}}],"samplers":[]}]
    ));
}

test "load bot" {
    var model = try gltf_loader.load(testing.io, testing.allocator, "models/bot/bot.gltf");
    defer model.deinit();

    try testing.expectEqual(2, model.parts.len);
    try testing.expectEqual(27, model.nodes.len);
    try testing.expectEqual(25, model.skins[0].joints.len);
    try testing.expectEqual(75, model.clips[0].tracks.len);
}
