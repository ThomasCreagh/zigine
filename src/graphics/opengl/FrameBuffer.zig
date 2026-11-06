const std = @import("std");
const c = @import("../../c.zig");
const Texture = @import("Texture.zig");

const gl = c.glad;

const FrameBuffer = @This();

pub const Error = error{
    FrameBufferIncomplete,
};

id: gl.GLuint = 0,
depth: Texture = .{},
width: gl.GLsizei,
height: gl.GLsizei,
restore_viewport: [4]gl.GLint = .{ 0, 0, 0, 0 },

pub fn initDepth(width: gl.GLsizei, height: gl.GLsizei) !FrameBuffer {
    var depth: Texture = .{};

    gl.glGenTextures(1, &depth.id);
    errdefer depth.deinit();

    gl.glBindTexture(gl.GL_TEXTURE_2D, depth.id);
    defer gl.glBindTexture(gl.GL_TEXTURE_2D, 0);

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_DEPTH_COMPONENT24,
        width,
        height,
        0,
        gl.GL_DEPTH_COMPONENT,
        gl.GL_FLOAT,
        null,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MIN_FILTER,
        gl.GL_NEAREST,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MAG_FILTER,
        gl.GL_NEAREST,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_S,
        gl.GL_CLAMP_TO_BORDER,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_T,
        gl.GL_CLAMP_TO_BORDER,
    );

    const border = [_]gl.GLfloat{ 1.0, 1.0, 1.0, 1.0 };
    gl.glTexParameterfv(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_BORDER_COLOR,
        &border,
    );

    var id: gl.GLuint = 0;

    gl.glGenFramebuffers(1, &id);
    errdefer gl.glDeleteFramebuffers(1, &id);

    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, id);
    defer gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);

    gl.glFramebufferTexture2D(
        gl.GL_FRAMEBUFFER,
        gl.GL_DEPTH_ATTACHMENT,
        gl.GL_TEXTURE_2D,
        depth.id,
        0,
    );

    gl.glDrawBuffer(gl.GL_NONE);
    gl.glReadBuffer(gl.GL_NONE);

    const status = gl.glCheckFramebufferStatus(gl.GL_FRAMEBUFFER);
    if (status != gl.GL_FRAMEBUFFER_COMPLETE) {
        std.debug.print("Framebuffer incomplete: 0x{x}\n", .{status});
        return Error.FrameBufferIncomplete;
    }

    return .{
        .id = id,
        .depth = depth,
        .width = width,
        .height = height,
    };
}

pub fn bind(self: *FrameBuffer) void {
    gl.glGetIntegerv(gl.GL_VIEWPORT, &self.restore_viewport);
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, self.id);
    gl.glViewport(0, 0, self.width, self.height);
}

pub fn unbind(self: *const FrameBuffer) void {
    const viewport = self.restore_viewport;
    gl.glBindFramebuffer(gl.GL_FRAMEBUFFER, 0);
    gl.glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
}

pub fn clear(_: *const FrameBuffer) void {
    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);
}

pub fn beginDepthPass(self: *FrameBuffer) void {
    self.bind();
    self.clear();
    gl.glEnable(gl.GL_POLYGON_OFFSET_FILL);
    gl.glPolygonOffset(2.0, 4.0);
}

pub fn endDepthPass(self: *const FrameBuffer) void {
    gl.glDisable(gl.GL_POLYGON_OFFSET_FILL);
    self.unbind();
}

pub fn deinit(self: *FrameBuffer) void {
    gl.glDeleteFramebuffers(1, &self.id);
    self.id = 0;
    self.depth.deinit();
}
