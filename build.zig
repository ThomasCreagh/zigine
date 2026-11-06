const std = @import("std");
const Translator = @import("translate_c").Translator;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glfw_dep = b.dependency("glfw_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const glad_dep = b.dependency("zig_glad", .{
        .target = target,
        .optimize = optimize,
    });

    const zalgebra = b.dependency("zalgebra", .{
        .target = target,
        .optimize = optimize,
    });

    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("zigine", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    mod.linkLibrary(glfw_dep.artifact("glfw"));
    mod.linkLibrary(glad_dep.artifact("glad"));

    mod.addImport("zalgebra", zalgebra.module("zalgebra"));
    mod.addImport("zigimg", zigimg.module("zigimg"));

    mod.link_libc = true;

    const translate_c = b.dependency("translate_c", .{});

    const translator: Translator = .init(translate_c, .{
        .c_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    translator.addIncludePath(glfw_dep.artifact("glfw").getEmittedIncludeTree());
    translator.addIncludePath(glad_dep.artifact("glad").getEmittedIncludeTree());

    if (b.graph.environ_map.get("GL_HEADERS")) |gl_headers| {
        const gl_include: std.Build.LazyPath = .{ .cwd_relative = b.pathJoin(&.{ gl_headers, "include" }) };
        mod.addSystemIncludePath(gl_include);
        translator.addSystemIncludePath(gl_include);
    }

    mod.addImport("c", translator.mod);

    const exe = b.addExecutable(.{
        .name = "zigine",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zigine", .module = mod },
            },
        }),
    });

    exe.root_module.linkLibrary(glfw_dep.artifact("glfw"));
    exe.root_module.linkLibrary(glad_dep.artifact("glad"));

    exe.root_module.addImport("zalgebra", zalgebra.module("zalgebra"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    run_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
