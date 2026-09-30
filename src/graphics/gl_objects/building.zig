const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const shader_loader = @import("../shader_loader.zig");
const texture_loader = @import("../texture_loader.zig");

const gl = c.glad;
const stb = c.stb;
const Io = std.Io;

pub const Building = struct {
    position: zalg.Vec3 = zalg.Vec3.new(0, 0, 0), // Position of the box
    scale: zalg.Vec3 = zalg.Vec3.new(1, 1, 1), // Size of the box in each axis

    // Vertex definition for a canonical box
    vertex_buffer_data: [72]gl.GLfloat = .{
        // Front face
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,

        // Back face
        1.0,  -1.0, -1.0,
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  -1.0,
        1.0,  1.0,  -1.0,

        // Left face
        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
        -1.0, 1.0,  1.0,
        -1.0, 1.0,  -1.0,

        // Right face
        1.0,  -1.0, 1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        1.0,  1.0,  1.0,

        // Top face
        -1.0, 1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,

        // Bottom face
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  -1.0, 1.0,
        -1.0, -1.0, 1.0,
    },

    color_buffer_data: [72]gl.GLfloat = .{
        // Front, red
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0,
        1.0, 0.0, 0.0,

        // Back, yellow
        1.0, 1.0, 0.0,
        1.0, 1.0, 0.0,
        1.0, 1.0, 0.0,
        1.0, 1.0, 0.0,

        // Left, green
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,
        0.0, 1.0, 0.0,

        // Right, cyan
        0.0, 1.0, 1.0,
        0.0, 1.0, 1.0,
        0.0, 1.0, 1.0,
        0.0, 1.0, 1.0,

        // Top, blue
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,
        0.0, 0.0, 1.0,

        // Bottom, magenta
        1.0, 0.0, 1.0,
        1.0, 0.0, 1.0,
        1.0, 0.0, 1.0,
        1.0, 0.0, 1.0,
    },

    // 12 triangle faces of a box
    index_buffer_data: [36]gl.GLuint = .{
        0,  1,  2,
        0,  2,  3,

        4,  5,  6,
        4,  6,  7,

        8,  9,  10,
        8,  10, 11,

        12, 13, 14,
        12, 14, 15,

        16, 17, 18,
        16, 18, 19,

        20, 21, 22,
        20, 22, 23,
    },

    uv_buffer_data: [32]gl.GLfloat = .{
        // Front
        1.0, 1.0,
        2.0, 1.0,
        2.0, 0.0,
        1.0, 0.0,

        // Back
        3.0, 1.0,
        4.0, 1.0,
        4.0, 0.0,
        3.0, 0.0,

        // Left
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        0.0, 0.0,

        // Right
        2.0, 1.0,
        3.0, 1.0,
        3.0, 0.0,
        2.0, 0.0,
    },

    // OpenGL buffers
    vertex_array_id: gl.GLuint = 0,
    vertex_buffer_id: gl.GLuint = 0,
    index_buffer_id: gl.GLuint = 0,
    color_buffer_id: gl.GLuint = 0,
    uv_buffer_id: gl.GLuint = 0,
    texture_id: gl.GLuint = 0,

    // Shader variable IDs
    mvp_matrix_id: gl.GLint = 0,
    texture_sampler_id: gl.GLint = 0,
    program_id: gl.GLuint = 0,

    const Self = @This();

    pub fn initialize(
        self: *Self,
        io: Io,
        allocator: std.mem.Allocator,
        position: zalg.Vec3,
        scale: zalg.Vec3,
        texture_path: [:0]const u8,
    ) !void {
        // Define position and scale of the building geometry
        self.position = position;
        self.scale = scale;

        for (0..16) |i| {
            self.uv_buffer_data[2 * i + 1] *= scale.data[1];
        }

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

        // Create a vertex buffer object to store the UV data
        gl.glGenBuffers(1, &self.uv_buffer_id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.uv_buffer_id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.uv_buffer_data)),
            &self.uv_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        // Create an index buffer object to store the index data that defines triangle faces
        gl.glGenBuffers(1, &self.index_buffer_id);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.index_buffer_id);
        gl.glBufferData(
            gl.GL_ELEMENT_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.index_buffer_data)),
            &self.index_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        // Create and compile our GLSL program from the shaders
        self.program_id = try shader_loader.loadShaders(
            io,
            allocator,
            "assets/shaders/building.vert",
            "assets/shaders/building.frag",
        );
        if (self.program_id == 0) {
            std.debug.print("Failed to load shaders.\n", .{});
        }

        // Get a handle for our "MVP" uniform
        self.mvp_matrix_id = gl.glGetUniformLocation(self.program_id, "MVP");

        // Load a texture
        self.texture_id = try texture_loader.loadTextureTileBox(texture_path);

        // Get a handle to texture sampler
        self.texture_sampler_id = gl.glGetUniformLocation(self.program_id, "textureSampler");
    }

    pub fn render(self: *Self, camera_matrix: zalg.Mat4) void {
        gl.glUseProgram(self.program_id);
        gl.glBindVertexArray(self.vertex_array_id);

        gl.glEnableVertexAttribArray(0);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glEnableVertexAttribArray(1);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.color_buffer_id);
        gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        // Enable UV buffer
        gl.glEnableVertexAttribArray(2);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.uv_buffer_id);
        gl.glVertexAttribPointer(2, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.index_buffer_id);

        // Model transform: scale the box along each axis to make it look like
        // a building, then move it to its position in the world.
        const model = zalg.Mat4.fromTranslate(self.position)
            .mul(zalg.Mat4.fromScale(self.scale));

        // Set model-view-projection matrix
        const mvp = camera_matrix.mul(model);
        gl.glUniformMatrix4fv(
            self.mvp_matrix_id,
            1,
            gl.GL_FALSE,
            @ptrCast(&mvp.data[0][0]),
        );

        // Bind the texture to unit 0 and point the sampler at it
        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);
        gl.glUniform1i(self.texture_sampler_id, 0);

        // Draw the box
        gl.glDrawElements(
            gl.GL_TRIANGLES, // mode
            36, // number of indices
            gl.GL_UNSIGNED_INT, // type
            null, // element array buffer offset
        );

        gl.glDisableVertexAttribArray(0);
        gl.glDisableVertexAttribArray(1);
        gl.glDisableVertexAttribArray(2);
    }

    pub fn cleanup(self: *Self) void {
        gl.glDeleteBuffers(1, &self.vertex_buffer_id);
        gl.glDeleteBuffers(1, &self.color_buffer_id);
        gl.glDeleteBuffers(1, &self.index_buffer_id);
        gl.glDeleteBuffers(1, &self.uv_buffer_id);
        gl.glDeleteVertexArrays(1, &self.vertex_array_id);
        gl.glDeleteTextures(1, &self.texture_id);
        gl.glDeleteProgram(self.program_id);
    }
};
