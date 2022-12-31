const std = @import("std");
const Builder = std.build.Builder;
const Mode = std.builtin.Mode;

pub const pkg = std.build.Pkg{
    .name = "zig-obj",
    .source = .{ .path = rootDir() ++ "/src/main.zig" },
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig-obj", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    // Set package path to root directory to allow access to examples/ dir
    main_tests.main_pkg_path = ".";

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

inline fn rootDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
