const std = @import("std");
const Builder = std.build.Builder;
const Mode = std.builtin.Mode;

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
