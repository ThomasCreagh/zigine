const std = @import("std");
const c = @import("../../c.zig");
const zalg = @import("zalgebra");

const glfw = c.glfw;
const gl = c.glad;
const Io = std.Io;

const Shader = @This();

pub const Error = error{
    VertexShaderCreationFailed,
    VertexShaderNotFound,
    VertexCompilationFailed,
    FragmentShaderCreationFailed,
    FragmentShaderNotFound,
    FragmentCompilationFailed,
    ProgramCreationFailed,
    ProgramLinkingFailed,
    OpenGLError,
};

id: u32,

pub fn init(
    io: Io,
    allocator: std.mem.Allocator,
    vertex_file_path: []const u8,
    fragment_file_path: []const u8,
) !Shader {
    var result: gl.GLint = gl.GL_FALSE;
    var info_log_length: gl.GLint = 0;

    // create and read in vertex
    const vs: u32 = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    if (vs == 0) return Error.VertexShaderCreationFailed;
    defer gl.glDeleteShader(vs);

    const vs_code = std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        vertex_file_path,
        allocator,
        .unlimited,
    ) catch return Error.VertexShaderNotFound;
    defer allocator.free(vs_code);

    // Compile Vertex Shader
    std.debug.print("Compiling shader: {s}\n", .{vertex_file_path});
    const vertex_source_ptr: [*c]const u8 = vs_code.ptr;
    const vertex_len: gl.GLint = @intCast(vs_code.len);
    gl.glShaderSource(vs, 1, &vertex_source_ptr, &vertex_len);
    gl.glCompileShader(vs);

    // Check Vertex Shader
    gl.glGetShaderiv(vs, gl.GL_COMPILE_STATUS, &result);
    gl.glGetShaderiv(vs, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const error_message = try allocator.alloc(
            u8,
            @intCast(info_log_length + 1),
        );
        defer allocator.free(error_message);
        gl.glGetShaderInfoLog(vs, info_log_length, null, error_message.ptr);
        std.debug.print("{s}\n", .{error_message});
    }

    // Check result
    if (result == gl.GL_FALSE) return Error.VertexCompilationFailed;

    // create and read in fragment
    const fs: u32 = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    if (fs == 0) return Error.FragmentShaderCreationFailed;
    defer gl.glDeleteShader(fs);

    const fs_code = std.Io.Dir.readFileAlloc(
        std.Io.Dir.cwd(),
        io,
        fragment_file_path,
        allocator,
        .unlimited,
    ) catch return Error.FragmentShaderNotFound;
    defer allocator.free(fs_code);

    // Compile Fragment Shader
    std.debug.print("Compiling shader: {s}\n", .{fragment_file_path});
    const fragment_source_ptr: [*c]const u8 = fs_code.ptr;
    const fragment_len: gl.GLint = @intCast(fs_code.len);
    gl.glShaderSource(fs, 1, &fragment_source_ptr, &fragment_len);
    gl.glCompileShader(fs);

    // Check Fragment Shader
    gl.glGetShaderiv(fs, gl.GL_COMPILE_STATUS, &result);
    gl.glGetShaderiv(fs, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const error_message = try allocator.alloc(
            u8,
            @intCast(info_log_length + 1),
        );
        defer allocator.free(error_message);
        gl.glGetShaderInfoLog(fs, info_log_length, null, error_message.ptr);
        std.debug.print("{s}\n", .{error_message});
    }

    // Check result
    if (result == gl.GL_FALSE) return Error.FragmentCompilationFailed;

    // Link the program
    std.debug.print("Linking program\n", .{});
    const program_id: u32 = gl.glCreateProgram();
    if (program_id == 0) return Error.ProgramCreationFailed;
    errdefer gl.glDeleteProgram(program_id);

    gl.glAttachShader(program_id, vs);
    gl.glAttachShader(program_id, fs);
    defer {
        gl.glDetachShader(program_id, vs);
        gl.glDetachShader(program_id, fs);
    }
    gl.glLinkProgram(program_id);

    // Check the program
    gl.glGetProgramiv(program_id, gl.GL_LINK_STATUS, &result);
    gl.glGetProgramiv(program_id, gl.GL_INFO_LOG_LENGTH, &info_log_length);
    if (info_log_length > 0) {
        const program_error_message = try allocator.alloc(
            u8,
            @intCast(info_log_length + 1),
        );
        defer allocator.free(program_error_message);
        gl.glGetProgramInfoLog(
            program_id,
            info_log_length,
            null,
            program_error_message.ptr,
        );
        std.debug.print("{s}\n", .{program_error_message});
    }

    // check result
    if (result == gl.GL_FALSE) return Error.ProgramLinkingFailed;

    return .{ .id = program_id };
}

pub fn bind(self: *Shader) void {
    gl.glUseProgram(self.id);
}

pub fn unbind(self: *Shader) void {
    _ = self;
    gl.glUseProgram(0);
}

pub fn deinit(self: *Shader) void {
    gl.glDeleteProgram(self.id);
}
