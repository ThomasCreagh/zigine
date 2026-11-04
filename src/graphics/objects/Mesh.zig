const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const Transform = @import("../Transform.zig");
const Shader = @import("../opengl/Shader.zig");
const VertexArray = @import("../opengl/array.zig").VertexArray;
const VertexBuffer = @import("../opengl/buffer.zig").VertexBuffer;
const IndexBuffer = @import("../opengl/buffer.zig").IndexBuffer;
const SceneObject = @import("../SceneObject.zig");

const gl = c.glad;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Mesh = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .update = update,
    .getTransform = getTransform,
    .deinit = deinit,
};

transform: Transform = .{},
enable: bool = true,

vao: VertexArray,
position_vbo: VertexBuffer,
colour_vbo: VertexBuffer,
normal_vbo: VertexBuffer,
index_vbo: IndexBuffer,

index_buffer_len: usize,

mvp_matrix_id: gl.GLint = 0,
program: *Shader,

pub fn init(
    allocator: std.mem.Allocator,
    program: *Shader,
    vertex_buffer_data: []const f32,
    colour_buffer_data: []const f32,
    index_buffer_data: []const u32,
) !*Mesh {
    const self = try allocator.create(Mesh);
    errdefer allocator.destroy(self);

    const vao = VertexArray.init();
    errdefer vao.deinit();

    const position_vbo = VertexBuffer.init(vertex_buffer_data);
    errdefer position_vbo.deinit();

    position_vbo.bind();
    vao.enableAttrib(0, 3);

    const colour_vbo = VertexBuffer.init(colour_buffer_data);
    errdefer colour_vbo.deinit();

    colour_vbo.bind();
    vao.enableAttrib(1, 3);

    const normal_buffer_data = try allocator.alloc(f32, vertex_buffer_data.len);
    defer allocator.free(normal_buffer_data);
    setNormals(normal_buffer_data, vertex_buffer_data);
    const normal_vbo = VertexBuffer.init(normal_buffer_data);
    errdefer normal_vbo.deinit();

    normal_vbo.bind();
    vao.enableAttrib(2, 3);

    const index_vbo = IndexBuffer.init(index_buffer_data);
    errdefer index_vbo.deinit();

    index_vbo.bind();

    const mvp_matrix_id = gl.glGetUniformLocation(program.id, "MVP");

    self.* = .{
        .vao = vao,
        .position_vbo = position_vbo,
        .colour_vbo = colour_vbo,
        .normal_vbo = normal_vbo,
        .index_vbo = index_vbo,
        .index_buffer_len = index_buffer_data.len,
        .program = program,
        .mvp_matrix_id = mvp_matrix_id,
    };

    return self;
}

pub fn render(ptr: *anyopaque, view: zalg.Mat4, projection: zalg.Mat4) void {
    const self: *Mesh = @ptrCast(@alignCast(ptr));

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
    gl.glDrawElements(
        gl.GL_TRIANGLES, // mode
        @intCast(self.index_buffer_len), // number of indices
        gl.GL_UNSIGNED_INT, // type
        null, // element array buffer offset
    );
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
    self.colour_vbo.deinit();
    self.normal_vbo.deinit();
    self.index_vbo.deinit();
    allocator.destroy(self);
}

fn setNormals(normal_array: []f32, vertex_array: []const f32) void {
    for (0..5) |i_p| {
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
