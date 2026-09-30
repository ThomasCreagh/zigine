const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const shader_loader = @import("../shader_loader.zig");
const texture_loader = @import("../texture_loader.zig");

const gl = c.glad;
const Io = std.Io;

pub const Skybox = struct {
    // Unit cube vertices (24 verts, 4 per face)
    vertex_buffer_data: [72]gl.GLfloat = .{
        // Front (+Z)
        -1.0, -1.0, 1.0,
        1.0,  -1.0, 1.0,
        1.0,  1.0,  1.0,
        -1.0, 1.0,  1.0,

        // Back (-Z)
        1.0,  -1.0, -1.0,
        -1.0, -1.0, -1.0,
        -1.0, 1.0,  -1.0,
        1.0,  1.0,  -1.0,

        // Left (-X)
        -1.0, -1.0, -1.0,
        -1.0, -1.0, 1.0,
        -1.0, 1.0,  1.0,
        -1.0, 1.0,  -1.0,

        // Right (+X)
        1.0,  -1.0, 1.0,
        1.0,  -1.0, -1.0,
        1.0,  1.0,  -1.0,
        1.0,  1.0,  1.0,

        // Top (+Y)
        -1.0, 1.0,  1.0,
        1.0,  1.0,  1.0,
        1.0,  1.0,  -1.0,
        -1.0, 1.0,  -1.0,

        // Bottom (-Y)
        -1.0, -1.0, -1.0,
        1.0,  -1.0, -1.0,
        1.0,  -1.0, 1.0,
        -1.0, -1.0, 1.0,
    },

    // Winding flipped vs. the building box so faces point INWARD
    index_buffer_data: [36]gl.GLuint = .{
        0,  2,  1,  0,  3,  2,
        4,  6,  5,  4,  7,  6,
        8,  10, 9,  8,  11, 10,
        12, 14, 13, 12, 15, 14,
        16, 18, 17, 16, 19, 18,
        20, 22, 21, 20, 23, 22,
    },

    uv_buffer_data: [48]gl.GLfloat = .{
        // Front (+Z): col 1, row 1
        0.50, 2.0 / 3.0,
        0.25, 2.0 / 3.0,
        0.25, 1.0 / 3.0,
        0.50, 1.0 / 3.0,

        // Back (-Z): col 3, row 1
        1.00, 2.0 / 3.0,
        0.75, 2.0 / 3.0,
        0.75, 1.0 / 3.0,
        1.00, 1.0 / 3.0,

        // Left (-X): col 2, row 1
        0.75, 2.0 / 3.0,
        0.50, 2.0 / 3.0,
        0.50, 1.0 / 3.0,
        0.75, 1.0 / 3.0,

        // Right (+X): col 0, row 1
        0.25, 2.0 / 3.0,
        0.00, 2.0 / 3.0,
        0.00, 1.0 / 3.0,
        0.25, 1.0 / 3.0,

        // Top (+Y): col 1, row 0
        0.50, 1.0 / 3.0,
        0.25, 1.0 / 3.0,
        0.25, 0.0,
        0.50, 0.0,

        // Bottom (-Y): col 1, row 2
        0.50, 1.0,
        0.25, 1.0,
        0.25, 2.0 / 3.0,
        0.50, 2.0 / 3.0,
    },

    // OpenGL objects
    vertex_array_id: gl.GLuint = 0,
    vertex_buffer_id: gl.GLuint = 0,
    index_buffer_id: gl.GLuint = 0,
    uv_buffer_id: gl.GLuint = 0,
    texture_id: gl.GLuint = 0,

    // Shader handles
    vp_matrix_id: gl.GLint = 0,
    texture_sampler_id: gl.GLint = 0,
    program_id: gl.GLuint = 0,

    const Self = @This();

    pub fn initialize(
        self: *Self,
        io: Io,
        allocator: std.mem.Allocator,
        texture_path: [:0]const u8,
    ) !void {
        self.texture_id = try texture_loader.loadSkyBox(texture_path);

        var tex_w: gl.GLint = 0;
        var tex_h: gl.GLint = 0;
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);
        gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_WIDTH, &tex_w);
        gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_HEIGHT, &tex_h);
        insetUVs(&self.uv_buffer_data, @floatFromInt(tex_w), @floatFromInt(tex_h));

        gl.glGenVertexArrays(1, &self.vertex_array_id);
        gl.glBindVertexArray(self.vertex_array_id);

        gl.glGenBuffers(1, &self.vertex_buffer_id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.vertex_buffer_data)),
            &self.vertex_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        gl.glGenBuffers(1, &self.uv_buffer_id);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.uv_buffer_id);
        gl.glBufferData(
            gl.GL_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.uv_buffer_data)),
            &self.uv_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        gl.glGenBuffers(1, &self.index_buffer_id);
        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.index_buffer_id);
        gl.glBufferData(
            gl.GL_ELEMENT_ARRAY_BUFFER,
            @sizeOf(@TypeOf(self.index_buffer_data)),
            &self.index_buffer_data,
            gl.GL_STATIC_DRAW,
        );

        self.program_id = try shader_loader.loadShaders(
            io,
            allocator,
            "assets/shaders/skybox.vert",
            "assets/shaders/skybox.frag",
        );
        if (self.program_id == 0) {
            std.debug.print("Failed to load skybox shaders.\n", .{});
        }

        self.vp_matrix_id = gl.glGetUniformLocation(self.program_id, "VP");
        self.texture_sampler_id = gl.glGetUniformLocation(self.program_id, "textureSampler");
    }

    pub fn render(self: *Self, view: zalg.Mat4, projection: zalg.Mat4) void {
        // Remove translation: zero the 4th column's xyz
        var sky_view = view;
        sky_view.data[3][0] = 0;
        sky_view.data[3][1] = 0;
        sky_view.data[3][2] = 0;

        const vp = projection.mul(sky_view);

        // Skybox depth is forced to 1.0 in the shader, so it must pass LEQUAL
        gl.glDepthFunc(gl.GL_LEQUAL);

        gl.glUseProgram(self.program_id);
        gl.glBindVertexArray(self.vertex_array_id);

        gl.glEnableVertexAttribArray(0);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.vertex_buffer_id);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glEnableVertexAttribArray(1);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, self.uv_buffer_id);
        gl.glVertexAttribPointer(1, 2, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, self.index_buffer_id);

        gl.glUniformMatrix4fv(
            self.vp_matrix_id,
            1,
            gl.GL_FALSE,
            @ptrCast(&vp.data[0][0]),
        );

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);
        gl.glUniform1i(self.texture_sampler_id, 0);

        gl.glDrawElements(gl.GL_TRIANGLES, 36, gl.GL_UNSIGNED_INT, null);

        gl.glDisableVertexAttribArray(0);
        gl.glDisableVertexAttribArray(1);

        gl.glDepthFunc(gl.GL_LESS);
    }

    fn insetUVs(uvs: *[48]gl.GLfloat, tex_w: f32, tex_h: f32) void {
        const du = 0.5 / tex_w;
        const dv = 0.5 / tex_h;

        for (0..6) |face| {
            const base = face * 8;

            var mid_u: f32 = 0;
            var mid_v: f32 = 0;
            for (0..4) |i| {
                mid_u += uvs[base + 2 * i];
                mid_v += uvs[base + 2 * i + 1];
            }
            mid_u /= 4;
            mid_v /= 4;

            for (0..4) |i| {
                const u = &uvs[base + 2 * i];
                const v = &uvs[base + 2 * i + 1];
                u.* += if (u.* < mid_u) du else -du;
                v.* += if (v.* < mid_v) dv else -dv;
            }
        }
    }

    pub fn cleanup(self: *Self) void {
        gl.glDeleteBuffers(1, &self.vertex_buffer_id);
        gl.glDeleteBuffers(1, &self.index_buffer_id);
        gl.glDeleteBuffers(1, &self.uv_buffer_id);
        gl.glDeleteVertexArrays(1, &self.vertex_array_id);
        gl.glDeleteTextures(1, &self.texture_id);
        gl.glDeleteProgram(self.program_id);
    }
};
