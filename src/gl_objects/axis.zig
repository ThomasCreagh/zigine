const std = @import("std");
const c = @import("c.zig");
const zalg = @import("zalgebra");
const glfw = c.glfw;
const gl = c.glad;

// Wherever your shader sources / loader live, e.g.:
const shaders = @import("shaders.zig"); // expects cube_vertex_shader, cube_fragment_shader, loadShadersFromString

/// A structure for visualizing the global 3D coordinate system.
pub const Axis = struct {
    vertex_buffer_data: [18]gl.GLfloat = .{
        // X axis
        0.0,   0.0,   0.0,
        100.0, 0.0,   0.0,

        // Y axis
        0.0,   0.0,   0.0,
        0.0,   100.0, 0.0,

        // Z axis
        0.0,   0.0,   0.0,
        0.0,   0.0,   100.0,
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

    // OpenGL buffers
    vertex_array_id: gl.GLuint = 0,
    vertex_buffer_id: gl.GLuint = 0,
    color_buffer_id: gl.GLuint = 0,

    // Shader variable IDs
    mvp_matrix_id: gl.GLint = 0,
    program_id: gl.GLuint = 0,

    const Self = @This();

    pub fn initialize(self: *Self) void {
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
        self.program_id = shaders.loadShadersFromString(
            shaders.cube_vertex_shader,
            shaders.cube_fragment_shader,
        );
        if (self.program_id == 0) {
            std.debug.print("Failed to load shaders.\n", .{});
        }

        // Get a handle for our "MVP" uniform
        self.mvp_matrix_id = gl.glGetUniformLocation(self.program_id, "MVP");
    }

    pub fn render(self: *Self, camera_matrix: zalg.Mat4) void {
        gl.glUseProgram(self.program_id);

        gl.glEnableVertexAttribArray(0);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glEnableVertexAttribArray(1);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.color_buffer_id);
        gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        var mvp = camera_matrix;
        gl.glUniformMatrix4fv(self.mvp_matrix_id, 1, gl.GL_FALSE, @ptrCast(&mvp.data[0][0]));

        // Draw the lines
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
