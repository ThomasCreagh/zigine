const std = @import("std");
const z = @import("zigine");

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    try z.run(io, allocator);
}
