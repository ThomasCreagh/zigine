const std = @import("std");
const c = @import("c.zig");
const zalg = @import("zalgebra");
const glfw = c.glfw;
const gl = c.glad;

const Io = std.Io;

pub fn run(io: Io, allocator: std.mem.Allocator) !void {
    _ = glfw.glfwSetErrorCallback(errorCallback);
    if (glfw.glfwInit() == 0) {
        std.debug.print("Failed glfw init\n", .{});
        return;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 3);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_FORWARD_COMPAT, glfw.GL_TRUE); // For MacOS
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(1920, 1080, "zingine", null, null);
    if (window == null) {
        std.debug.print("Failed window open\n", .{});
        return;
    }
    defer glfw.glfwDestroyWindow(window);

    // Ensure we can capture the escape key being pressed below
    glfw.glfwSetInputMode(window, glfw.GLFW_STICKY_KEYS, glfw.GL_TRUE);
    _ = glfw.glfwSetKeyCallback(window, keyCallback);

    glfw.glfwMakeContextCurrent(window);
    glfw.glfwSwapInterval(1); // vsync

    const loader: gl.GLADloadproc = @ptrCast(&glfw.glfwGetProcAddress);
    if (gl.gladLoadGLLoader(loader) == 0) {
        std.debug.print("Failed to load gl loader\n", .{});
        return;
    }

    const projection = zalg.Mat4.perspective(45.0, 4.0 / 3.0, 0.1, 100.0);
    const view = zalg.Mat4.lookAt(
        zalg.Vec3.new(0, 0, 3), // pos
        zalg.Vec3.new(0, 0, 0), // look at origin
        zalg.Vec3.new(0, 1, 0), // up vector
    );

    gl.glClearColor(0.1, 0.1, 0.1, 1.0);

    const vertices: [3][3]f32 = .{
        .{ -0.5, -0.5, 0.0 },
        .{ 0.5, -0.5, 0.0 },
        .{ 0.0, 0.5, 0.0 },
    };

    const colours: [3][3]f32 = .{
        .{ 1.0, 0.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
        .{ 0.0, 0.0, 1.0 },
    };

    var vertex_array_id: u32 = 0;
    gl.glGenVertexArrays(1, &vertex_array_id);
    gl.glBindVertexArray(vertex_array_id);
    defer gl.glDeleteVertexArrays(1, &vertex_array_id);

    var vertex_buffer_id: u32 = 0;
    gl.glGenBuffers(1, &vertex_buffer_id);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vertex_buffer_id);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(f32) * 9, &vertices, gl.GL_STATIC_DRAW);
    defer gl.glDeleteBuffers(1, &vertex_buffer_id);

    var colour_buffer_id: u32 = 0;
    gl.glGenBuffers(1, &colour_buffer_id);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, colour_buffer_id);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(f32) * 9, &colours, gl.GL_STATIC_DRAW);
    defer gl.glDeleteBuffers(1, &colour_buffer_id);

    const program_id: u32 = try loadShaders(
        io,
        allocator,
        "assets/triangle.vert",
        "assets/triangle.frag",
    );
    if (program_id == 0) {
        std.debug.print("Failed to load shaders\n", .{});
        return;
    }
    defer gl.glDeleteProgram(program_id);

    const matrix_id: gl.GLint = gl.glGetUniformLocation(program_id, "mvp");

    var z_offset: f32 = -1.0;
    var direction: f32 = -1.0;

    while (glfw.glfwWindowShouldClose(window) == 0) {
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);

        if (z_offset <= -2.0 and direction == -1.0) direction = 1.0;
        if (z_offset >= 2.0 and direction == 1.0) direction = -1.0;
        z_offset += 0.1 * direction;

        const time: f32 = @floatCast(glfw.glfwGetTime());
        const angle: f32 = time * 50.0;

        const model = zalg.Mat4.fromTranslate(zalg.Vec3.new(0, 0, z_offset))
            .mul(zalg.Mat4.fromRotation(angle, zalg.Vec3.new(0, 1, 0)));

        const mvp = zalg.Mat4.mul(projection, zalg.Mat4.mul(view, model));

        gl.glUseProgram(program_id);
        gl.glUniformMatrix4fv(matrix_id, 1, gl.GL_FALSE, &mvp.data[0][0]);

        gl.glEnableVertexAttribArray(0);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, vertex_buffer_id);
        gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glEnableVertexAttribArray(1);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, colour_buffer_id);
        gl.glVertexAttribPointer(1, 3, gl.GL_FLOAT, gl.GL_FALSE, 0, null);

        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 3);

        // helpful for errors
        const err = gl.glGetError();
        if (err != gl.GL_NO_ERROR) {
            std.debug.print("GL error: {}\n", .{err});
        }

        gl.glDisableVertexAttribArray(0);
        gl.glDisableVertexAttribArray(1);

        glfw.glfwPollEvents();
        glfw.glfwSwapBuffers(window);
    }
}

// Is called whenever a key is pressed/released via GLFW
fn keyCallback(
    window: ?*glfw.GLFWwindow,
    key: c_int,
    scancode: c_int,
    action: c_int,
    mode: c_int,
) callconv(.c) void {
    _ = scancode;
    _ = mode;

    if (key == glfw.GLFW_KEY_SPACE and action == glfw.GLFW_PRESS) {
        std.debug.print("space pressed\n", .{});
    }

    if (key == glfw.GLFW_KEY_A and action == glfw.GLFW_PRESS) {
        std.debug.print("(A) key pressed\n", .{});
    }

    if (key == glfw.GLFW_KEY_ESCAPE and action == glfw.GLFW_PRESS) {
        glfw.glfwSetWindowShouldClose(window, gl.GL_TRUE);
    }
}

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

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.c) void {
    std.debug.print("GLFW Error {}: {s}\n", .{ err, description });
}
