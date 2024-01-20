const std = @import("std");

test "zig-obj" {
    std.testing.refAllDecls(@import("src/main.zig"));
}
