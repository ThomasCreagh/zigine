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

const MovingBuilding = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .update = update,
    .getTransform = getTransform,
    .deinit = deinit,
};

const vertex_buffer_data: [72]gl.GLfloat = .{
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
};

const colour_buffer_data: [72]gl.GLfloat = .{
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
};

// 12 triangle faces of a box
const index_buffer_data: [36]gl.GLuint = .{
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
};

const base_uv_buffer_data: [32]gl.GLfloat = .{
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
};

uv_buffer_data: [32]gl.GLfloat,

transform: Transform = .{},
enable: bool = true,

vao: VertexArray,
position_vbo: VertexBuffer,
colour_vbo: VertexBuffer,
uv_vbo: VertexBuffer,
index_vbo: IndexBuffer,
texture_id: gl.GLuint = 0,

mvp_matrix_id: gl.GLint = 0,
texture_sampler_id: gl.GLint = 0,
program: Shader,

rng: std.Random.IoSource,
velocity: f32 = 0,
target_velocity: f32 = 0,

pub fn init(
    io: Io,
    allocator: std.mem.Allocator,
    texture_path: [:0]const u8,
) !*MovingBuilding {
    const self = try allocator.create(MovingBuilding);
    errdefer allocator.destroy(self);

    const vao = VertexArray.init();
    errdefer vao.deinit();

    const position_vbo = VertexBuffer.init(&vertex_buffer_data);
    errdefer position_vbo.deinit();

    position_vbo.bind();
    vao.enableAttrib(0, 3);

    const colour_vbo = VertexBuffer.init(&colour_buffer_data);
    errdefer colour_vbo.deinit();

    colour_vbo.bind();
    vao.enableAttrib(1, 3);

    var uv_data = base_uv_buffer_data;

    const uv_vbo = VertexBuffer.init(&uv_data);
    errdefer uv_vbo.deinit();

    uv_vbo.bind();
    vao.enableAttrib(2, 2);

    const index_vbo = IndexBuffer.init(&index_buffer_data);
    errdefer index_vbo.deinit();
    index_vbo.bind();

    var program = try Shader.init(
        io,
        allocator,
        "assets/shaders/building.vert",
        "assets/shaders/building.frag",
    );
    errdefer program.deinit();

    const mvp_matrix_id = gl.glGetUniformLocation(program.id, "MVP");

    // update
    // Load a texture
    const texture_id = try texture_loader.loadTextureTileBox(texture_path);

    // Get a handle to texture sampler
    const texture_sampler_id = gl.glGetUniformLocation(program.id, "textureSampler");

    self.program.bind();
    gl.glUniform1i(self.texture_sampler_id, 0);

    self.* = .{
        .uv_buffer_data = uv_data,
        .vao = vao,
        .position_vbo = position_vbo,
        .colour_vbo = colour_vbo,
        .index_vbo = index_vbo,
        .uv_vbo = uv_vbo,
        .program = program,
        .texture_id = texture_id,
        .texture_sampler_id = texture_sampler_id,
        .mvp_matrix_id = mvp_matrix_id,
        .rng = .{ .io = io },
    };

    return self;
}

pub fn render(ptr: *anyopaque, view: zalg.Mat4, projection: zalg.Mat4) void {
    const self: *MovingBuilding = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    const model = self.transform.matrix();

    const view_projection = zalg.Mat4.mul(projection, view);
    const mvp = zalg.Mat4.mul(view_projection, model);

    self.program.bind();
    self.vao.bind();

    gl.glUniformMatrix4fv(
        self.mvp_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&mvp.data[0][0]),
    );

    // Bind the texture to unit 0 and point the sampler at it
    gl.glActiveTexture(gl.GL_TEXTURE0);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.texture_id);

    // Draw the box
    gl.glDrawElements(
        gl.GL_TRIANGLES, // mode
        36, // number of indices
        gl.GL_UNSIGNED_INT, // type
        null, // element array buffer offset
    );
}

pub fn update(ptr: *anyopaque, dt: f32) void {
    const self: *MovingBuilding = @ptrCast(@alignCast(ptr));
    const rand = self.rng.interface();

    const curve: f32 = 2.0;
    const dir_change_sec: f32 = 2.0;
    const move_speed: f32 = 0.5;

    if (rand.float(f32) < 1.0 - @exp(-dir_change_sec * dt)) {
        self.target_velocity = rand.float(f32) * dir_change_sec - 1.0;
    }

    const smooth = 1.0 - @exp(-curve * dt);

    self.velocity +=
        (self.target_velocity - self.velocity) * smooth;

    const move = self.velocity * move_speed * dt;

    self.transform.scale.data[1] =
        @max(1.0, self.transform.scale.data[1] + move);

    const y_scale = self.transform.scale.data[1];

    self.transform.position.data[1] = y_scale;

    for (0..16) |i| {
        const uv_index = i * 2;

        self.uv_buffer_data[uv_index] =
            base_uv_buffer_data[uv_index];

        self.uv_buffer_data[uv_index + 1] =
            base_uv_buffer_data[uv_index + 1] * y_scale;
    }

    self.uv_vbo.bind();

    gl.glBufferSubData(
        gl.GL_ARRAY_BUFFER,
        0,
        @intCast(self.uv_buffer_data.len * @sizeOf(f32)),
        &self.uv_buffer_data,
    );
}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *MovingBuilding = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn sceneObject(self: *MovingBuilding) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *MovingBuilding = @ptrCast(@alignCast(ptr));
    self.vao.deinit();
    self.position_vbo.deinit();
    self.colour_vbo.deinit();
    self.index_vbo.deinit();
    self.uv_vbo.deinit();
    self.program.deinit();
    gl.glDeleteTextures(1, &self.texture_id);
    allocator.destroy(self);
}
