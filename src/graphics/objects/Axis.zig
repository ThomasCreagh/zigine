const std = @import("std");
const zalg = @import("zalgebra");

const c = @import("../../c.zig");
const Transform = @import("../Transform.zig");
const Shader = @import("../Shader.zig");
const VertexArray = @import("../opengl/array.zig").VertexArray;
const VertexBuffer = @import("../opengl/buffer.zig").VertexBuffer;
const SceneObject = @import("../SceneObject.zig");

const gl = c.glad;
const Io = std.Io;
const Axis = @This();

const vtable: SceneObject.VTable = .{
    .render = render,
    .getTransform = getTransform,
    .deinit = deinit,
};

transform: Transform = .{},

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

colour_buffer_data: [18]gl.GLfloat = .{
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

vao: VertexArray,
position_vbo: VertexBuffer,
colour_vbo: VertexBuffer,

// Shader variable IDs
mvp_matrix_id: gl.GLint = 0,
program: Shader,

pub fn init(self: *Axis, io: Io, allocator: std.mem.Allocator) !void {
    self.vao = VertexArray.init();

    self.position_vbo = VertexBuffer.init(&self.vertex_buffer_data);
    self.position_vbo.bind();
    self.vao.enableAttrib(0, 3);

    self.colour_vbo = VertexBuffer.init(&self.colour_buffer_data);
    self.colour_vbo.bind();
    self.vao.enableAttrib(1, 3);

    self.program = try Shader.init(
        io,
        allocator,
        "assets/shaders/axis.vert",
        "assets/shaders/axis.frag",
    );

    // Get a handle for our "MVP" uniform
    self.mvp_matrix_id = gl.glGetUniformLocation(self.program.id, "MVP");
}

pub fn render(ptr: *anyopaque, view: zalg.Mat4, projection: zalg.Mat4) void {
    const self: *Axis = @ptrCast(@alignCast(ptr));
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
    gl.glDrawArrays(gl.GL_LINES, 0, 6);
}

pub fn getTransform(ptr: *anyopaque) *Transform {
    const self: *Axis = @ptrCast(@alignCast(ptr));
    return &self.transform;
}

pub fn sceneObject(self: *Axis) SceneObject {
    return .{
        .ptr = self,
        .vtable = &vtable,
    };
}

pub fn deinit(ptr: *anyopaque) void {
    const self: *Axis = @ptrCast(@alignCast(ptr));
    self.vao.deinit();
    self.position_vbo.deinit();
    self.colour_vbo.deinit();
    self.program.deinit();
}
