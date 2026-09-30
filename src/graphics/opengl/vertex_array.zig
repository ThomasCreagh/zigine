const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const shader_loader = @import("../shader_loader.zig");
const buffer = @import("buffer.zig");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

pub const VertexArray = struct {
    id: u32,
    vbo: buffer.VertexBuffer,
    ibo: buffer.IndexBuffer,

    const Self = @This();

    pub fn init(vertices: []const f32, indices: []const u32) Self {
        var vao: u32 = 0;

        gl.glGenVertexArrays(1, &vao);
        gl.glBindVertexArray(vao);

        return .{
            .id = vao,
            .vbo = buffer.VertexBuffer.init(vertices),
            .ibo = buffer.IndexBuffer.init(indices),
        };
    }

    pub fn bind(self: Self) void {
        gl.glBindVertexArray(self.id);
    }

    pub fn unbind(self: Self) void {
        _ = self;
        gl.glBindVertexArray(0);
    }
};
