const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{
        .preferred_optimize_mode = .ReleaseFast,
    });

    const mod = b.addModule("cat", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.linkSystemLibrary("glfw3", .{
        .preferred_link_mode = .static,
    });
    mod.linkSystemLibrary("GL", .{
        .preferred_link_mode = .static,
    });
    mod.linkSystemLibrary("assimp", .{
        .preferred_link_mode = .static,
    });
    mod.linkSystemLibrary("ncurses", .{
        .preferred_link_mode = .static,
    });
    mod.addLibraryPath(b.path("evil")); // evil evil evil hack
    mod.linkSystemLibrary("freetype2", .{
        .preferred_link_mode = .static,
    });

    mod.addCSourceFile(.{ .file = b.path("src/lib.c") });
    mod.addCSourceFile(.{ .file = b.path("src/fonts.c") });

    mod.addIncludePath(b.path("src"));
    mod.addIncludePath(b.path("evil/freetype2")); // more evil

    const zmath = b.dependency("zmath", .{});
    mod.addImport("zmath", zmath.module("root"));

    const lib = b.addLibrary(.{
        .name = "cat",
        .linkage = std.builtin.LinkMode.dynamic,
        .root_module = mod,
    });

    b.installArtifact(lib);
}
