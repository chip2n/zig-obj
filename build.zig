const std = @import("std");
const Builder = std.build.Builder;
const Mode = std.builtin.Mode;


pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule(.{
        .name = "obj",
        .source_file = .{ .path = "src/main.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "zig-obj",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.install();

    var main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Set package path to root directory to allow access to examples/ dir
    main_tests.main_pkg_path = ".";

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

inline fn rootDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
