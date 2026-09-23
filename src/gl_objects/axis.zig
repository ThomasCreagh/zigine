const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../c.zig");
const shader_loader = @import("../shader_loader.zig");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

/// A structure for visualizing the global 3D coordinate system.
pub const Axis = struct {
    vertex_buffer_data: [18]gl.GLfloat = .{
        // X axis
        0.0, 0.0, 0.0,
        2.0, 0.0, 0.0,

        // Y axis
        0.0, 0.0, 0.0,
        0.0, 2.0, 0.0,

        // Z axis
        0.0, 0.0, 0.0,
        0.0, 0.0, 2.0,
    },

    color_buffer_data: [18]gl.GLfloat = .{
        // X, red
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0,

        // Y, green
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,

        // Z, blue
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
    },

    position: zalg.Vec3 = zalg.Vec3.new(0, 0, 0),
    rotation_angle: f32 = 0.0,

    // OpenGL buffers
    vertex_array_id: gl.GLuint = 0,
    vertex_buffer_id: gl.GLuint = 0,
    color_buffer_id: gl.GLuint = 0,

    // Shader variable IDs
    mvp_matrix_id: gl.GLint = 0,
    program_id: gl.GLuint = 0,

    const Self = @This();

    pub fn initialize(self: *Self, io: Io, allocator: std.mem.Allocator) !void {
        // Create a vertex array object
        gl.glGenVertexArrays(1, &self.vertex_array_id);
        gl.glBindVertexArray(self.vertex_array_id);

        // Create a vertex buffer object to store the vertex data
        gl.glGenBuffers(1, &self.vertex_buffer_id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.vertex_buffer_data)),
            &self.vertex_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        // Create a vertex buffer object to store the color data
        gl.glGenBuffers(1, &self.color_buffer_id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.color_buffer_id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.color_buffer_data)),
            &self.color_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        // Create and compile our GLSL program from the shaders
        self.program_id = try shader_loader.loadShaders(
            io,
            allocator,
            "assets/axis.vert",
            "assets/axis.frag",
        );
        if (self.program_id == 0) {
            std.debug.print("Failed to load shaders.\n", .{});
        }

        // Get a handle for our "MVP" uniform
        self.mvp_matrix_id = gl.glGetUniformLocation(self.program_id, "MVP");
    }

    pub fn render(self: *Self, view_projection: zalg.Mat4) void {
        const model = zalg.Mat4.fromTranslate(self.position)
            .mul(zalg.Mat4.fromRotation(self.rotation_angle, zalg.Vec3.new(0, 1, 0)));
        const mvp = zalg.Mat4.mul(view_projection, model);

        gl.glUseProgram(self.program_id);

        gl.glEnableVertexAttribArray(0);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glEnableVertexAttribArray(1);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.color_buffer_id);
        gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        // Draw the lines
        gl.glUniformMatrix4fv(self.mvp_matrix_id, 1, gl.GL_FALSE, @ptrCast(&mvp.data[0][0]));
        gl.glDrawArrays(gl.GL_LINES, 0, 6);

        gl.glDisableVertexAttribArray(0);
        gl.glDisableVertexAttribArray(1);
    }

    pub fn cleanup(self: *Self) void {
        gl.glDeleteBuffers(1, &self.vertex_buffer_id);
        gl.glDeleteBuffers(1, &self.color_buffer_id);
        gl.glDeleteVertexArrays(1, &self.vertex_array_id);
        gl.glDeleteProgram(self.program_id);
    }
};
