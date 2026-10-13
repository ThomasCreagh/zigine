const std = @import("std");
const c = @import("../../c.zig");

const gl = c.glad;
const stb = c.stb;

const Texture = @This();

pub const WrapMode = enum {
    repeat,
    clamp_to_edge,
};

pub const FilterMode = enum {
    linear,
    linear_mipmap_linear,
};

id: gl.GLuint = 0,

pub fn init2D(
    path: [:0]const u8,
    wrap: WrapMode,
    min_filter: FilterMode,
    generate_mipmaps: bool,
) !Texture {
    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;

    const image = stb.stbi_load(
        path.ptr,
        &w,
        &h,
        &channels,
        3,
    );

    if (image == null) {
        std.debug.print("Failed to load texture: {s}\n", .{path});
        return error.TextureLoadFailed;
    }

    defer stb.stbi_image_free(image);

    var id: gl.GLuint = 0;

    gl.glGenTextures(1, &id);
    errdefer gl.glDeleteTextures(1, &id);

    gl.glBindTexture(gl.GL_TEXTURE_2D, id);

    const wrap_value: gl.GLenum = switch (wrap) {
        .repeat => gl.GL_REPEAT,
        .clamp_to_edge => gl.GL_CLAMP_TO_EDGE,
    };

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_S,
        @intCast(wrap_value),
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_T,
        @intCast(wrap_value),
    );

    const min_filter_value: gl.GLenum = switch (min_filter) {
        .linear => gl.GL_LINEAR,
        .linear_mipmap_linear => gl.GL_LINEAR_MIPMAP_LINEAR,
    };

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MIN_FILTER,
        @intCast(min_filter_value),
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MAG_FILTER,
        gl.GL_LINEAR,
    );

    gl.glPixelStorei(gl.GL_UNPACK_ALIGNMENT, 1);

    gl.glTexImage2D(
        gl.GL_TEXTURE_2D,
        0,
        gl.GL_RGB,
        w,
        h,
        0,
        gl.GL_RGB,
        gl.GL_UNSIGNED_BYTE,
        image,
    );

    if (generate_mipmaps) {
        gl.glGenerateMipmap(gl.GL_TEXTURE_2D);
    }

    return .{
        .id = id,
    };
}

pub fn initTileBox(path: [:0]const u8) !Texture {
    return init2D(
        path,
        .repeat,
        .linear_mipmap_linear,
        true,
    );
}

pub fn initSkybox(path: [:0]const u8) !Texture {
    return init2D(
        path,
        .clamp_to_edge,
        .linear,
        false,
    );
}

pub fn bind(self: *const Texture, unit: u32) void {
    const texture_unit: gl.GLenum =
        @as(gl.GLenum, @intCast(gl.GL_TEXTURE0)) +
        @as(gl.GLenum, @intCast(unit));
    gl.glActiveTexture(texture_unit);
    gl.glBindTexture(gl.GL_TEXTURE_2D, self.id);
}

pub fn unbind(_: *const Texture) void {
    gl.glBindTexture(gl.GL_TEXTURE_2D, 0);
}

pub fn deinit(self: *Texture) void {
    gl.glDeleteTextures(1, &self.id);
    self.id = 0;
}
