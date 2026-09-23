const std = @import("std");
const c = @import("c.zig");
const zalg = @import("zalgebra");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

pub fn loadShaders(
    io: Io,
    allocator: std.mem.Allocator,
    vertex_file_path: []const u8,
    fragment_file_path: []const u8,
) !u32 {
    // Create the shaders
    const vertex_shader_id: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    const fragment_shader_id: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);

    // Read the Vertex Shader code from the file
    const vertex_shader_code = std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        vertex_file_path,
        allocator,
        .unlimited,
    ) catch {
        std.debug.print("Vertex shader not found {s}.\n", .{vertex_file_path});
        return 0;
    };
    defer allocator.free(vertex_shader_code);

    // Read the Fragment Shader code from the file
    const fragment_shader_code = std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        fragment_file_path,
        allocator,
        .unlimited,
    ) catch {
        std.debug.print("Fragment shader not found {s}.\n", .{fragment_file_path});
        return 0;
    };
    defer allocator.free(fragment_shader_code);

    var result: gl.GLint = gl.GL_FALSE;
    var info_log_length: gl.GLint = 0;

    // Compile Vertex Shader
    std.debug.print("Compiling shader: {s}\n", .{vertex_file_path});
    const vertex_source_ptr: [*c]const u8 = vertex_shader_code.ptr;
    const vertex_len: gl.GLint = @intCast(vertex_shader_code.len);
    gl.glShaderSource(vertex_shader_id, 1, &vertex_source_ptr, &vertex_len);
    gl.glCompileShader(vertex_shader_id);

    // Check Vertex Shader
    gl.glGetShaderiv(vertex_shader_id, gl.GL_COMPILE_STATUS, &result);
    gl.glGetShaderiv(vertex_shader_id, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const error_message = try allocator.alloc(u8, @intCast(info_log_length + 1));
        defer allocator.free(error_message);
        gl.glGetShaderInfoLog(vertex_shader_id, info_log_length, null, error_message.ptr);
        std.debug.print("{s}\n", .{error_message});
    }

    // Check result
    if (result == gl.GL_FALSE) {
        std.debug.print("Shader compilation failed\n", .{});
        return 0;
    }

    // Compile Fragment Shader
    std.debug.print("Compiling shader: {s}\n", .{fragment_file_path});
    const fragment_source_ptr: [*c]const u8 = fragment_shader_code.ptr;
    const fragment_len: gl.GLint = @intCast(fragment_shader_code.len);
    gl.glShaderSource(fragment_shader_id, 1, &fragment_source_ptr, &fragment_len);
    gl.glCompileShader(fragment_shader_id);

    // Check Fragment Shader
    gl.glGetShaderiv(fragment_shader_id, gl.GL_COMPILE_STATUS, &result);
    gl.glGetShaderiv(fragment_shader_id, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const error_message = try allocator.alloc(u8, @intCast(info_log_length + 1));
        defer allocator.free(error_message);
        gl.glGetShaderInfoLog(fragment_shader_id, info_log_length, null, error_message.ptr);
        std.debug.print("{s}\n", .{error_message});
    }

    // Check result
    if (result == gl.GL_FALSE) {
        std.debug.print("Shader compilation failed\n", .{});
        return 0;
    }

    // Link the program
    std.debug.print("Linking program\n", .{});
    const program_id: u32 = gl.glCreateProgram();
    gl.glAttachShader(program_id, vertex_shader_id);
    gl.glAttachShader(program_id, fragment_shader_id);
    gl.glLinkProgram(program_id);

    // Check the program
    gl.glGetProgramiv(program_id, gl.GL_LINK_STATUS, &result);
    gl.glGetProgramiv(program_id, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const program_error_message = try allocator.alloc(u8, @intCast(info_log_length + 1));
        defer allocator.free(program_error_message);
        gl.glGetProgramInfoLog(program_id, info_log_length, null, program_error_message.ptr);
        std.debug.print("{s}\n", .{program_error_message});
    }

    gl.glDetachShader(program_id, vertex_shader_id);
    gl.glDetachShader(program_id, fragment_shader_id);

    gl.glDeleteShader(vertex_shader_id);
    gl.glDeleteShader(fragment_shader_id);

    return program_id;
}
