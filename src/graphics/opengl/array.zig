const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const shader_loader = @import("../shader_loader.zig");

const gl = c.glad;

pub const VertexArray = struct {
    id: u32,

    const Self = @This();

    pub fn init() Self {
        var vao: u32 = 0;

        gl.glGenVertexArrays(1, &vao);
        gl.glBindVertexArray(vao);

        return .{
            .id = vao,
        };
    }

    pub fn bind(self: Self) void {
        gl.glBindVertexArray(self.id);
    }

    pub fn unbind(self: Self) void {
        _ = self;
        gl.glBindVertexArray(0);
    }

    pub fn deinit(self: Self) void {
        gl.glDeleteVertexArrays(1, self.id);
    }

    pub fn enableAttrib(
        self: Self,
        index: u32,
        size: i32,
    ) void {
        self.bind();
        gl.glEnableVertexAttribArray(index);
        gl.glVertexAttribPointer(
            index,
            size,
            gl.GL_FLOAT,
            gl.GL_FALSE,
            0,
            null,
        );
    }
};
