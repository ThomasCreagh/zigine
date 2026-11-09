const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const Transform = @import("../Transform.zig");
const Material = @import("../Material.zig");
const Shader = @import("../opengl/Shader.zig");
const VertexArray = @import("../opengl/array.zig").VertexArray;
const VertexBuffer = @import("../opengl/buffer.zig").VertexBuffer;
const IndexBuffer = @import("../opengl/buffer.zig").IndexBuffer;
const SceneObject = @import("../SceneObject.zig");
const RenderContext = @import("../RenderContext.zig");

const gl = c.glad;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Mesh = @This();

pub const MeshData = @import("../MeshData.zig");

const vtable: SceneObject.VTable = .{
    .render = render,
    .renderShadow = renderShadow,
    .update = update,
    .getTransform = getTransform,
    .deinit = deinit,
};

transform: Transform = .{},
enable: bool = true,
material: Material = .{},

vao: VertexArray,
position_vbo: VertexBuffer,
colour_vbo: ?VertexBuffer,
normal_vbo: VertexBuffer,
uv_vbo: ?VertexBuffer,
index_vbo: IndexBuffer,

index_buffer_len: usize,

mvp_matrix_id: gl.GLint = 0,
model_matrix_id: gl.GLint = 0,
light_vp_matrix_id: gl.GLint = 0,
depth_mvp_matrix_id: gl.GLint = 0,
light_position_id: gl.GLint = 0,
light_intensity_id: gl.GLint = 0,
shadow_map_id: gl.GLint = 0,
diffuse_colour_id: gl.GLint = 0,
diffuse_texture_id: gl.GLint = 0,
has_diffuse_texture_id: gl.GLint = 0,
program: *Shader,
depth_program: *Shader,

pub fn init(
    allocator: std.mem.Allocator,
    program: *Shader,
    depth_program: *Shader,
    data: MeshData,
) !*Mesh {
    const self = try allocator.create(Mesh);
    errdefer allocator.destroy(self);

    const vao = VertexArray.init();
    errdefer vao.deinit();

    const position_vbo = VertexBuffer.init(data.positions);
    errdefer position_vbo.deinit();

    position_vbo.bind();
    vao.enableAttrib(0, 3);

    const colour_vbo = initOptionalBuffer(vao, data.colours, 1, 3);
    errdefer if (colour_vbo) |vbo| vbo.deinit();

    var generated_normals: ?[]f32 = null;
    defer if (generated_normals) |normals| allocator.free(normals);

    const normals = data.normals orelse blk: {
        const generated = try allocator.alloc(f32, data.positions.len);
        generated_normals = generated;
        setNormals(generated, data.positions);
        break :blk generated;
    };

    const normal_vbo = VertexBuffer.init(normals);
    errdefer normal_vbo.deinit();

    normal_vbo.bind();
    vao.enableAttrib(2, 3);

    const uv_vbo = initOptionalBuffer(vao, data.uvs, 3, 2);
    errdefer if (uv_vbo) |vbo| vbo.deinit();

    const index_vbo = IndexBuffer.init(data.indices);
    errdefer index_vbo.deinit();

    index_vbo.bind();

    const mvp_matrix_id = gl.glGetUniformLocation(program.id, "MVP");
    const model_matrix_id = gl.glGetUniformLocation(program.id, "model");
    const light_vp_matrix_id = gl.glGetUniformLocation(program.id, "lightVP");
    const depth_mvp_matrix_id = gl.glGetUniformLocation(depth_program.id, "MVP");
    const light_position_id = gl.glGetUniformLocation(program.id, "lightPosition");
    const light_intensity_id = gl.glGetUniformLocation(program.id, "lightIntensity");
    const shadow_map_id = gl.glGetUniformLocation(program.id, "shadowMap");
    const diffuse_colour_id = gl.glGetUniformLocation(program.id, "diffuseColour");
    const diffuse_texture_id = gl.glGetUniformLocation(program.id, "diffuseTexture");
    const has_diffuse_texture_id = gl.glGetUniformLocation(program.id, "hasDiffuseTexture");

    self.* = .{
        .vao = vao,
        .position_vbo = position_vbo,
        .colour_vbo = colour_vbo,
        .normal_vbo = normal_vbo,
        .uv_vbo = uv_vbo,
        .index_vbo = index_vbo,
        .index_buffer_len = data.indices.len,
        .program = program,
        .depth_program = depth_program,
        .mvp_matrix_id = mvp_matrix_id,
        .model_matrix_id = model_matrix_id,
        .light_vp_matrix_id = light_vp_matrix_id,
        .depth_mvp_matrix_id = depth_mvp_matrix_id,
        .light_position_id = light_position_id,
        .light_intensity_id = light_intensity_id,
        .shadow_map_id = shadow_map_id,
        .diffuse_colour_id = diffuse_colour_id,
        .diffuse_texture_id = diffuse_texture_id,
        .has_diffuse_texture_id = has_diffuse_texture_id,
    };

    return self;
}

pub fn render(ptr: *anyopaque, ctx: RenderContext) void {
    const self: *Mesh = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    const view = ctx.view;
    const projection = ctx.projection;

    const model = self.transform.matrix();

    const view_projection = zalg.Mat4.mul(projection, view);
    const mvp = zalg.Mat4.mul(view_projection, model);

    self.program.bind();

    gl.glUniformMatrix4fv(
        self.mvp_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&mvp.data[0][0]),
    );

    gl.glUniformMatrix4fv(
        self.model_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&model.data[0][0]),
    );

    gl.glUniformMatrix4fv(
        self.light_vp_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&ctx.light_view_projection.data[0][0]),
    );

    switch (ctx.light.*) {
        .pointlight => |light| {
            gl.glUniform3fv(self.light_position_id, 1, @ptrCast(&light.position.data));
            gl.glUniform3fv(self.light_intensity_id, 1, @ptrCast(&light.intensity.data));
        },
    }

    gl.glUniform1i(self.shadow_map_id, RenderContext.shadow_map_unit);

    gl.glUniform3fv(self.diffuse_colour_id, 1, @ptrCast(&self.material.diffuse_colour.data));
    gl.glUniform1i(self.diffuse_texture_id, RenderContext.diffuse_unit);
    gl.glUniform1i(
        self.has_diffuse_texture_id,
        @intFromBool(self.material.diffuse_texture != null),
    );

    if (self.material.diffuse_texture) |texture| {
        texture.bind(RenderContext.diffuse_unit);
    }

    self.draw();
}

pub fn renderShadow(ptr: *anyopaque, ctx: RenderContext) void {
    const self: *Mesh = @ptrCast(@alignCast(ptr));

    if (self.enable == false) return;

    const model = self.transform.matrix();

    const mvp = zalg.Mat4.mul(ctx.light_view_projection, model);

    self.depth_program.bind();

    gl.glUniformMatrix4fv(
        self.depth_mvp_matrix_id,
        1,
        gl.GL_FALSE,
        @ptrCast(&mvp.data[0][0]),
    );

    self.draw();
}

pub fn update(_: *anyopaque, _: f32) void {}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *Mesh = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn sceneObject(self: *Mesh) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Mesh = @ptrCast(@alignCast(ptr));
    self.vao.deinit();
    self.position_vbo.deinit();
    if (self.colour_vbo) |vbo| vbo.deinit();
    self.normal_vbo.deinit();
    if (self.uv_vbo) |vbo| vbo.deinit();
    self.index_vbo.deinit();
    allocator.destroy(self);
}

fn draw(self: *const Mesh) void {
    self.vao.bind();

    gl.glDrawElements(
        gl.GL_TRIANGLES, // mode
        @intCast(self.index_buffer_len), // number of indices
        gl.GL_UNSIGNED_INT, // type
        null, // element array buffer offset
    );
}

fn initOptionalBuffer(
    vao: VertexArray,
    buffer_data: ?[]const f32,
    attrib: u32,
    size: i32,
) ?VertexBuffer {
    const vertices = buffer_data orelse return null;

    const vbo = VertexBuffer.init(vertices);
    vbo.bind();
    vao.enableAttrib(attrib, size);

    return vbo;
}

fn setNormals(normal_array: []f32, vertex_array: []const f32) void {
    for (0..vertex_array.len / 12) |i_p| {
        const i = i_p * 12;

        const vec1 = zalg.Vec3.new(
            vertex_array[i],
            vertex_array[i + 1],
            vertex_array[i + 2],
        );
        const vec2 = zalg.Vec3.new(
            vertex_array[i + 3],
            vertex_array[i + 4],
            vertex_array[i + 5],
        );
        const vec3 = zalg.Vec3.new(
            vertex_array[i + 6],
            vertex_array[i + 7],
            vertex_array[i + 8],
        );

        const edge1 = zalg.Vec3.sub(vec2, vec1);
        const edge2 = zalg.Vec3.sub(vec3, vec1);

        const cross_prod = zalg.Vec3.cross(edge1, edge2);
        const normal = zalg.Vec3.norm(cross_prod);

        for (0..4) |v| {
            normal_array[i + (v * 3)] = normal.data[0];
            normal_array[i + (v * 3) + 1] = normal.data[1];
            normal_array[i + (v * 3) + 2] = normal.data[2];
        }
    }
}
