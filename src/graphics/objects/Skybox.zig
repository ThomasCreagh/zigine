const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const Transform = @import("../Transform.zig");
const Shader = @import("../opengl/Shader.zig");
const VertexArray = @import("../opengl/array.zig").VertexArray;
const VertexBuffer = @import("../opengl/buffer.zig").VertexBuffer;
const IndexBuffer = @import("../opengl/buffer.zig").IndexBuffer;
const SceneObject = @import("../SceneObject.zig");

const texture_loader = @import("../texture_loader.zig"); // change

const gl = c.glad;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Skybox = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .update = update,
    .getTransform = getTransform,
    .deinit = deinit,
};

// Unit cube vertices (24 verts, 4 per face)
const vertex_buffer_data: [72]gl.GLfloat = .{
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
};

// Winding flipped vs. the building box so faces point INWARD
const index_buffer_data: [36]gl.GLuint = .{
    0,  2,  1,  0,  3,  2,
    4,  6,  5,  4,  7,  6,
    8,  10, 9,  8,  11, 10,
    12, 14, 13, 12, 15, 14,
    16, 18, 17, 16, 19, 18,
    20, 22, 21, 20, 23, 22,
};

var uv_buffer_data: [48]gl.GLfloat = .{
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
};

transform: Transform = .{},
enable: bool = true,

vao: VertexArray,
position_vbo: VertexBuffer,
uv_vbo: VertexBuffer,
index_vbo: IndexBuffer,
texture_id: gl.GLuint = 0,

vp_matrix_id: gl.GLint = 0,
texture_sampler_id: gl.GLint = 0,
program: Shader,

pub fn init(
    io: Io,
    allocator: std.mem.Allocator,
    texture_path: [:0]const u8,
) !*Skybox {
    // update
    // Load a texture
    const texture_id = try texture_loader.loadSkyBox(texture_path);

    var tex_w: gl.GLint = 0;
    var tex_h: gl.GLint = 0;
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture_id);
    gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_WIDTH, &tex_w);
    gl.glGetTexLevelParameteriv(gl.GL_TEXTURE_2D, 0, gl.GL_TEXTURE_HEIGHT, &tex_h);
    insetUVs(&uv_buffer_data, @floatFromInt(tex_w), @floatFromInt(tex_h));

    const self = try allocator.create(Skybox);
    errdefer allocator.destroy(self);

    const vao = VertexArray.init();
    errdefer vao.deinit();

    const position_vbo = VertexBuffer.init(&vertex_buffer_data);
    errdefer position_vbo.deinit();

    position_vbo.bind();
    vao.enableAttrib(0, 3);

    const uv_vbo = VertexBuffer.init(&uv_buffer_data);
    errdefer uv_vbo.deinit();

    uv_vbo.bind();
    vao.enableAttrib(1, 2);

    const index_vbo = IndexBuffer.init(&index_buffer_data);
    errdefer index_vbo.deinit();
    index_vbo.bind();

    var program = try Shader.init(
        io,
        allocator,
        "assets/shaders/skybox.vert",
        "assets/shaders/skybox.frag",
    );
    errdefer program.deinit();

    const vp_matrix_id = gl.glGetUniformLocation(program.id, "VP");

    // Get a handle to texture sampler
    const texture_sampler_id = gl.glGetUniformLocation(program.id, "textureSampler");

    program.bind();
    gl.glUniform1i(self.texture_sampler_id, 0);
    std.debug.print("texture sampler: {}\n", .{texture_sampler_id});

    self.* = .{
        .vao = vao,
        .position_vbo = position_vbo,
        .index_vbo = index_vbo,
        .uv_vbo = uv_vbo,
        .program = program,
        .texture_id = texture_id,
        .texture_sampler_id = texture_sampler_id,
        .vp_matrix_id = vp_matrix_id,
    };

    return self;
}

pub fn render(ptr: *anyopaque, view: zalg.Mat4, projection: zalg.Mat4) void {
    const self: *Skybox = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    // Remove translation: zero the 4th column's xyz
    var sky_view = view;
    sky_view.data[3][0] = 0;
    sky_view.data[3][1] = 0;
    sky_view.data[3][2] = 0;

    const vp = projection.mul(sky_view);

    self.program.bind();
    self.vao.bind();

    gl.glUniformMatrix4fv(
        self.vp_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&vp.data[0][0]),
    );

    // Bind the texture to unit 0 and point the sampler at it
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);

    // Skybox depth is forced to 1.0 in the shader, so it must pass LEQUAL
    gl.glDepthFunc(gl.GL_LEQUAL);

    gl.glDrawElements(gl.GL_TRIANGLES, 36, gl.GL_UNSIGNED_INT, null);

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

pub fn update(_: *anyopaque, _: f32) void {}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *Skybox = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn sceneObject(self: *Skybox) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Skybox = @ptrCast(@alignCast(ptr));
    self.vao.deinit();
    self.position_vbo.deinit();
    self.index_vbo.deinit();
    self.uv_vbo.deinit();
    self.program.deinit();
    gl.glDeleteTextures(1, &self.texture_id);
    allocator.destroy(self);
}
