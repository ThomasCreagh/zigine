const std = @import("std");
const obj_loader = @import("zigine").obj_loader;

const testing = std.testing;

fn load(arena: *std.heap.ArenaAllocator, obj: []const u8, mtl: []const u8) !obj_loader.Model {
    const allocator = arena.allocator();
    const parsed = try obj_loader.parseObj(allocator, obj);
    var materials: obj_loader.MaterialMap = .empty;
    try obj_loader.parseMtl(allocator, mtl, "models/test", &materials);
    return obj_loader.buildModel(allocator, &parsed, &materials);
}

const quad =
    \\v 0 0 0
    \\v 1 0 0
    \\v 1 1 0
    \\v 0 1 0
    \\vt 0 0
    \\vt 1 0
    \\vt 1 1
    \\vt 0 1
    \\vn 0 0 1
    \\
;

test "quad" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const model = try load(&arena, quad ++ "f 1/1/1 2/2/1 3/3/1 4/4/1\n", "");
    const part = model.parts[0];

    try testing.expectEqual(1, model.parts.len);
    try testing.expectEqualSlices(u32, &.{ 0, 1, 2, 0, 2, 3 }, part.data.indices);
    try testing.expectEqual(12, part.data.positions.len);
}

test "uv flip" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const model = try load(&arena, "v 0 0 0\nvn 0 0 1\nvt 0.5 0.25\nf 1/1/1 1/1/1 1/1/1\n", "");

    try testing.expectEqualSlices(f32, &.{ 0.5, 0.75 }, model.parts[0].data.uvs.?);
}

test "same position different uv" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const model = try load(&arena, quad ++ "f 1/1/1 2/2/1 3/3/1\nf 1/4/1 3/3/1 4/4/1\n", "");

    try testing.expectEqualSlices(u32, &.{ 0, 1, 2, 3, 2, 4 }, model.parts[0].data.indices);
}

test "no uvs" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const model = try load(&arena, quad ++ "f 1//1 2//1 3//1\n", "");

    try testing.expectEqualSlices(f32, &.{ 0, 0, 0, 0, 0, 0 }, model.parts[0].data.uvs.?);
    try testing.expectEqual(9, model.parts[0].data.normals.?.len);
}

test "indices across objects" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const obj = "o a\nv 0 0 0\nv 1 0 0\nv 2 0 0\nvn 0 0 1\no b\nv 3 0 0\nf 2//1 3//1 4//1\n";
    const model = try load(&arena, obj, "");

    try testing.expectEqualSlices(f32, &.{ 1, 0, 0, 2, 0, 0, 3, 0, 0 }, model.parts[0].data.positions);
}

test "negative indices" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const model = try load(&arena, quad ++ "f -3//-1 -2//-1 -1//-1\n", "");

    try testing.expectEqualSlices(f32, &.{ 1, 0, 0, 1, 1, 0, 0, 1, 0 }, model.parts[0].data.positions);
}

test "materials" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const obj = quad ++
        "usemtl a\nf 1//1 2//1 3//1\n" ++
        "usemtl b\nf 1//1 3//1 4//1\n" ++
        "usemtl a\nf 1//1 3//1 4//1\n" ++
        "usemtl unused\n";
    const model = try load(&arena, obj, "newmtl a\nKd 0.25 0.5 0.75\nnewmtl b\n");

    try testing.expectEqual(2, model.parts.len);
    try testing.expectEqual(6, model.parts[0].data.indices.len);
    try testing.expectEqual(3, model.parts[1].data.indices.len);
    try testing.expectEqual(0.5, model.parts[0].diffuse_colour.data[1]);
    try testing.expectEqual(1.0, model.parts[1].diffuse_colour.data[1]);
}

test "texture paths" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const obj = quad ++
        "usemtl a\nf 1//1 2//1 3//1\n" ++
        "usemtl b\nf 1//1 3//1 4//1\n" ++
        "usemtl c\nf 2//1 3//1 4//1\n";
    const mtl = "newmtl a\r\nmap_Kd Texture\\\\White Brick\\\\wall.png\r\n" ++
        "newmtl b\nmap_Kd one\\two.png\n" ++
        "newmtl c\n";
    const model = try load(&arena, obj, mtl);

    try testing.expectEqualStrings("models/test/Texture/White Brick/wall.png", model.parts[0].texture_path.?);
    try testing.expectEqualStrings("models/test/one/two.png", model.parts[1].texture_path.?);
    try testing.expectEqual(null, model.parts[2].texture_path);
}

test "bad faces" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    try testing.expectError(error.InvalidIndex, load(&arena, quad ++ "f 1//1 2//1 9//1\n", ""));
    try testing.expectError(error.InvalidIndex, load(&arena, quad ++ "f 0//1 2//1 3//1\n", ""));
    try testing.expectError(error.InvalidFace, load(&arena, quad ++ "f 1//1 2//1\n", ""));
    try testing.expectError(error.MissingNormals, load(&arena, quad ++ "f 1/1 2/2 3/3\n", ""));
}
