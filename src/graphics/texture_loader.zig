const std = @import("std");
const c = @import("../c.zig");

const stb = c.stb;
const gl = c.glad;
const Io = std.Io;

pub fn loadTextureTileBox(texture_file_path: [:0]const u8) !gl.GLuint {
    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;

    const img = stb.stbi_load(texture_file_path.ptr, &w, &h, &channels, 3);
    if (img == null) {
        std.debug.print("Failed to load texture {s}\n", .{texture_file_path});
        return error.TextureLoadFailed;
    }

    var texture: gl.GLuint = 0;
    gl.glGenTextures(1, &texture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);

    // To tile textures on a box, we set wrapping to repeat
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_REPEAT);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR_MIPMAP_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);

    // Tightly packed RGB rows (widths not divisible by 4 would otherwise skew)
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
        img,
    );
    gl.glGenerateMipmap(gl.GL_TEXTURE_2D);

    return texture;
}

pub fn loadSkyBox(texture_file_path: [:0]const u8) !gl.GLuint {
    var w: c_int = 0;
    var h: c_int = 0;
    var channels: c_int = 0;

    const img = stb.stbi_load(texture_file_path.ptr, &w, &h, &channels, 3);
    defer stb.stbi_image_free(img);
    if (img == null) {
        std.debug.print("Failed to load texture {s}\n", .{texture_file_path});
        return error.TextureLoadFailed;
    }

    var texture: gl.GLuint = 0;
    gl.glGenTextures(1, &texture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_S,
        gl.GL_CLAMP_TO_EDGE,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_WRAP_T,
        gl.GL_CLAMP_TO_EDGE,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MIN_FILTER,
        gl.GL_LINEAR,
    );

    gl.glTexParameteri(
        gl.GL_TEXTURE_2D,
        gl.GL_TEXTURE_MAG_FILTER,
        gl.GL_LINEAR,
    );

    // Tightly packed RGB rows (widths not divisible by 4 would otherwise skew)
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
        img,
    );
    // gl.glGenerateMipmap(gl.GL_TEXTURE_2D);

    return texture;
}
