const std = @import("std");

pub const parseObj = @import("obj.zig").parse;
pub const parseMtl = @import("mtl.zig").parse;

test "zig-obj" {
    std.testing.refAllDecls(@This());
}
