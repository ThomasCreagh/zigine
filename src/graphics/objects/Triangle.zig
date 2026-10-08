const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const Transform = @import("../Transform.zig");
const Shader = @import("../opengl/Shader.zig");
const VertexArray = @import("../opengl/array.zig").VertexArray;
const VertexBuffer = @import("../opengl/buffer.zig").VertexBuffer;
const SceneObject = @import("../SceneObject.zig");

const gl = c.glad;
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Triangle = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .update = update,
    .getTransform = getTransform,
    .deinit = deinit,
};

const vertex_buffer_data: [9]gl.GLfloat = .{
    // X axis
    -0.5, -0.5, 0.0,

    // Y axis
    0.5,  -0.5, 0.0,

    // Z axis
    0.0,  0.5,  0.0,
};

const colour_buffer_data: [9]gl.GLfloat = .{
    // red
    1.0, 0.0, 0.0,
    // green
    0.0, 1.0, 0.0,
    // blue
    0.0, 0.0, 1.0,
};

transform: Transform = .{},
enable: bool = true,

vao: VertexArray,
position_vbo: VertexBuffer,
colour_vbo: VertexBuffer,

// Shader variable IDs
mvp_matrix_id: gl.GLint = 0,
program: Shader,

pub fn init(io: Io, allocator: std.mem.Allocator) !*Triangle {
    const self = try allocator.create(Triangle);
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

    const program = try Shader.init(
        io,
        allocator,
        "assets/shaders/triangle.vert",
        "assets/shaders/triangle.frag",
    );
    errdefer program.deinit();

    const mvp_matrix_id = gl.glGetUniformLocation(program.id, "MVP");

    self.* = .{
        .vao = vao,
        .position_vbo = position_vbo,
        .colour_vbo = colour_vbo,
        .program = program,
        .mvp_matrix_id = mvp_matrix_id,
    };

    return self;
}

pub fn render(ptr: *anyopaque, view: zalg.Mat4, projection: zalg.Mat4) void {
    const self: *Triangle = @ptrCast(@alignCast(ptr));

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
    gl.glDrawArrays(gl.GL_TRIANGLES, 0, 3);
}

pub fn update(_: *anyopaque, _: f32) void {}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *Triangle = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn sceneObject(self: *Triangle) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Triangle = @ptrCast(@alignCast(ptr));
    self.vao.deinit();
    self.position_vbo.deinit();
    self.colour_vbo.deinit();
    self.program.deinit();
    allocator.destroy(self);
}
