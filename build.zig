const std = @import("std");
const Mode = std.builtin.Mode;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule(
        "obj",
        .{ .root_source_file = b.path("src/main.zig") },
    );

    const lib = b.addStaticLibrary(.{
        .name = "zig-obj",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = b.path("test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}

inline fn rootDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
