const std = @import("std");

const obj = @import("obj.zig");
const mtl = @import("mtl.zig");

pub const parseObj = obj.parse;
pub const parseObjCustom = obj.parseCustom;
pub const ObjData = obj.ObjData;
pub const Mesh = obj.Mesh;
pub const MeshMaterial = obj.MeshMaterial;
pub const ObjDefType = obj.DefType;

pub const parseMtl = mtl.parse;
pub const parseMtlCustom = mtl.parseCustom;
pub const MaterialData = mtl.MaterialData;
pub const Material = mtl.Material;
pub const TextureMap = mtl.TextureMap;
pub const MaterialKeyword = mtl.Keyword;

test "zig-obj" {
    std.testing.refAllDecls(@This());
}
