const std = @import("std");

const obj = @import("obj.zig");
const mtl = @import("mtl.zig");

pub const parseObj = obj.parse;
pub const ObjData = obj.ObjData;
pub const Mesh = obj.Mesh;

pub const parseMtl = mtl.parse;
pub const MaterialData = mtl.MaterialData;
pub const Material = mtl.Material;

test "zig-obj" {
    std.testing.refAllDecls(@This());
}
