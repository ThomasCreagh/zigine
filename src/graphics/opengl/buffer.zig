const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const shader_loader = @import("../shader_loader.zig");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

pub const VertexBuffer = struct {
    id: u32,

    const Self = @This();

    pub fn init(vertices: []const f32) Self {
        var vbo: Self = .{ .id = 0 };
        gl.glGenBuffers(1, &vbo.id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vbo.id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            vertices.len * @sizeOf(f32),
            vertices.ptr,
            gl.GL_STATIC_DRAW,
        );
        return vbo;
    }

    pub fn bind(self: Self) void {
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: Self) void {
        _ = self;
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    }
};

pub const IndexBuffer = struct {
    id: u32,
    count: usize,

    const Self = @This();

    pub fn init(indices: []const u32) Self {
        var ibo: Self = .{ .id = 0, .count = indices.len };
        gl.glGenBuffers(1, &ibo.id);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, ibo.id);
        gl.glBufferData(
            gl.GL_ELEMENT_ARRAY_BUFFER,
            indices.len * @sizeOf(f32),
            &indices,
            gl.GL_STATIC_DRAW,
        );
        return ibo;
    }

    pub fn bind(self: Self) void {
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.id);
    }

    pub fn unbind(self: Self) void {
        _ = self;
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, 0);
    }
};
