const std = @import("std");
const tokenize = std.mem.tokenize;
const split = std.mem.split;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;

const expect = std.testing.expect;
const expectError = std.testing.expectError;
const expectEqualSlices = std.testing.expectEqualSlices;

pub const ObjData = struct {
    vertices: []const f32,
    tex_coords: []const f32,
    normals: []const f32,

    meshes: []const Mesh,

    fn eq(self: ObjData, other: ObjData) bool {
        if (!std.mem.eql(f32, self.vertices, other.vertices)) return false;
        if (!std.mem.eql(f32, self.tex_coords, other.tex_coords)) return false;
        if (!std.mem.eql(f32, self.normals, other.normals)) return false;

        if (self.meshes.len != other.meshes.len) return false;
        for (self.meshes) |mesh, i| {
            if (!mesh.eq(other.meshes[i])) return false;
        }
        return true;
    }

    pub fn deinit(self: ObjData, allocator: Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.tex_coords);
        allocator.free(self.normals);

        for (self.meshes) |mesh| mesh.deinit(allocator);
        allocator.free(self.meshes);
    }
};

fn compareOpt(a: ?u32, b: ?u32) bool {
    if (a != null and b != null) {
        return a.? == b.?;
    }

    return a == null and b == null;
}

fn eqlZ(comptime T: type, a: ?[]const T, b: ?[]const T) bool {
    if (a != null and b != null) {
        return std.mem.eql(T, a.?, b.?);
    }

    return a == null and b == null;
}

pub const Mesh = struct {
    pub const Index = struct {
        vertex: ?u32,
        tex_coord: ?u32,
        normal: ?u32,

        fn eq(self: Mesh.Index, other: Mesh.Index) bool {
            return compareOpt(self.vertex, other.vertex) and
                compareOpt(self.tex_coord, other.tex_coord) and
                compareOpt(self.normal, other.normal);
        }
    };

    name: ?[]const u8,
    num_vertices: []const u32,
    indices: []const Mesh.Index,

    pub fn deinit(self: Mesh, allocator: Allocator) void {
        if (self.name) |name| allocator.free(name);
        allocator.free(self.num_vertices);
        allocator.free(self.indices);
    }

    fn eq(self: Mesh, other: Mesh) bool {
        if (!eqlZ(u8, self.name, other.name)) return false;
        if (self.indices.len != other.indices.len) return false;
        if (!std.mem.eql(u32, self.num_vertices, other.num_vertices)) return false;
        for (self.indices) |index, i| {
            if (!index.eq(other.indices[i])) return false;
        }
        return true;
    }
};

const DefType = enum {
    comment,
    vertex,
    tex_coord,
    normal,
    face,
    object,
    group,
    material_lib,
    use_material,
    smoothing,
    line,
    param_vertex,
};

pub fn parse(allocator: Allocator, data: []const u8) !ObjData {
    var vertices = ArrayList(f32).init(allocator);
    errdefer vertices.deinit();

    var tex_coords = ArrayList(f32).init(allocator);
    errdefer tex_coords.deinit();

    var normals = ArrayList(f32).init(allocator);
    errdefer normals.deinit();

    var meshes = ArrayList(Mesh).init(allocator);
    errdefer meshes.deinit();

    // current mesh
    var name: ?[]const u8 = null;
    var num_verts = ArrayList(u32).init(allocator);
    errdefer num_verts.deinit();
    var indices = ArrayList(Mesh.Index).init(allocator);
    errdefer indices.deinit();

    var lines = tokenize(u8, data, "\n");
    while (lines.next()) |line| {
        var iter = tokenize(u8, line, " ");
        const def_type = try parseType(iter.next().?);
        switch (def_type) {
            .vertex => {
                try vertices.append(try parseFloat(f32, iter.next().?));
                try vertices.append(try parseFloat(f32, iter.next().?));
                try vertices.append(try parseFloat(f32, iter.next().?));
            },
            .tex_coord => {
                try tex_coords.append(try parseFloat(f32, iter.next().?));
                try tex_coords.append(try parseFloat(f32, iter.next().?));
            },
            .normal => {
                try normals.append(try parseFloat(f32, iter.next().?));
                try normals.append(try parseFloat(f32, iter.next().?));
                try normals.append(try parseFloat(f32, iter.next().?));
            },
            .face => {
                var i: u32 = 0;
                while (iter.next()) |entry| {
                    var entry_iter = split(u8, entry, "/");
                    // TODO support x//y and similar
                    // NOTE obj is one-indexed - let's make it zero-indexed
                    try indices.append(.{
                        .vertex = if (entry_iter.next()) |e| (try parseOptionalIndex(e, vertices.items)) else null,
                        .tex_coord = if (entry_iter.next()) |e| (try parseOptionalIndex(e, tex_coords.items)) else null,
                        .normal = if (entry_iter.next()) |e| (try parseOptionalIndex(e, normals.items)) else null,
                    });

                    i += 1;
                }
                try num_verts.append(i);
            },
            .object => {
                if (num_verts.items.len > 0) {
                    try meshes.append(.{
                        .name = name,
                        .num_vertices = num_verts.toOwnedSlice(),
                        .indices = indices.toOwnedSlice(),
                    });
                }

                name = try allocator.dupe(u8, iter.next().?);
                num_verts = ArrayList(u32).init(allocator);
                errdefer num_verts.deinit();
                indices = ArrayList(Mesh.Index).init(allocator);
                errdefer indices.deinit();
            },
            else => {
                // ignore
            },
        }
    }

    // add last mesh (as long as it is not empty)
    if (num_verts.items.len > 0) {
        try meshes.append(Mesh{
            .name = name,
            .num_vertices = num_verts.toOwnedSlice(),
            .indices = indices.toOwnedSlice(),
        });
    }

    return ObjData{
        .vertices = vertices.toOwnedSlice(),
        .tex_coords = tex_coords.toOwnedSlice(),
        .normals = normals.toOwnedSlice(),
        .meshes = meshes.toOwnedSlice(),
    };
}

fn parseOptionalIndex(v: []const u8, indices: []f32) !?u32 {
    if (std.mem.eql(u8, v, "")) return null;
    const i = try parseInt(i32, v, 10);
    // const i = parseInt(i32, v, 10) catch |e| blk: {
    //     std.log.warn("Parsing: {}", .{v});
    //     break :blk 0;
    // };

    if (i < 0) {
        // index is relative to end of indices list, -1 meaning the last element
        return @intCast(u32, @intCast(i32, indices.len) + i);
    } else {
        return @intCast(u32, i) - 1;
    }
}

fn parseType(t: []const u8) !DefType {
    if (std.mem.eql(u8, t, "#")) {
        return .comment;
    } else if (std.mem.eql(u8, t, "v")) {
        return .vertex;
    } else if (std.mem.eql(u8, t, "vt")) {
        return .tex_coord;
    } else if (std.mem.eql(u8, t, "vn")) {
        return .normal;
    } else if (std.mem.eql(u8, t, "f")) {
        return .face;
    } else if (std.mem.eql(u8, t, "o")) {
        return .object;
    } else if (std.mem.eql(u8, t, "g")) {
        return .group;
    } else if (std.mem.eql(u8, t, "mtllib")) {
        return .material_lib;
    } else if (std.mem.eql(u8, t, "usemtl")) {
        return .use_material;
    } else if (std.mem.eql(u8, t, "s")) {
        return .smoothing;
    } else if (std.mem.eql(u8, t, "l")) {
        return .line;
    } else if (std.mem.eql(u8, t, "vp")) {
        return .param_vertex;
    } else {
        std.log.warn("Unknown type: {s}", .{t});
        return error.UnknownDefType;
    }
}

// ------------------------------------------------------------------------------

const test_allocator = std.testing.allocator;

test "unknown def" {
    try expectError(error.UnknownDefType, parse(test_allocator, "invalid 0 1 2"));
}

test "comment" {
    const result = try parse(test_allocator, "# this is a comment");
    defer result.deinit(test_allocator);

    try expect(result.vertices.len == 0);
    try expect(result.tex_coords.len == 0);
    try expect(result.normals.len == 0);
    try expect(result.meshes.len == 0);
}

test "single vertex def xyz" {
    var result = try parse(test_allocator, "v 0.123 0.234 0.345");
    defer result.deinit(test_allocator);

    try expect(std.mem.eql(f32, result.vertices, &[_]f32{ 0.123, 0.234, 0.345 }));
    try expect(result.tex_coords.len == 0);
    try expect(result.normals.len == 0);
    try expect(result.meshes.len == 0);
}

test "single vertex def xyzw" {
    var result = try parse(test_allocator, "v 0.123 0.234 0.345 0.456");
    defer result.deinit(test_allocator);

    try expect(std.mem.eql(f32, result.vertices, &[_]f32{ 0.123, 0.234, 0.345 }));
    try expect(result.tex_coords.len == 0);
    try expect(result.normals.len == 0);
    try expect(result.meshes.len == 0);
}

test "single tex coord def uv" {
    var result = try parse(test_allocator, "vt 0.123 0.234");
    defer result.deinit(test_allocator);

    try expect(std.mem.eql(f32, result.tex_coords, &[_]f32{ 0.123, 0.234 }));
    try expect(result.vertices.len == 0);
    try expect(result.normals.len == 0);
    try expect(result.meshes.len == 0);
}

test "single tex coord def uvw" {
    var result = try parse(test_allocator, "vt 0.123 0.234 0.345");
    defer result.deinit(test_allocator);

    try expect(std.mem.eql(f32, result.tex_coords, &[_]f32{ 0.123, 0.234 }));
    try expect(result.vertices.len == 0);
    try expect(result.normals.len == 0);
    try expect(result.meshes.len == 0);
}

test "single normal def xyz" {
    var result = try parse(test_allocator, "vn 0.123 0.234 0.345");
    defer result.deinit(test_allocator);

    try expect(std.mem.eql(f32, result.normals, &[_]f32{ 0.123, 0.234, 0.345 }));
    try expect(result.vertices.len == 0);
    try expect(result.tex_coords.len == 0);
    try expect(result.meshes.len == 0);
}

test "single face def vertex only" {
    var result = try parse(test_allocator, "f 1 2 3");
    defer result.deinit(test_allocator);

    const mesh = Mesh{
        .name = null,
        .num_vertices = &[_]u32{3},
        .indices = &[_]Mesh.Index{
            Mesh.Index{ .vertex = 0, .tex_coord = null, .normal = null },
            Mesh.Index{ .vertex = 1, .tex_coord = null, .normal = null },
            Mesh.Index{ .vertex = 2, .tex_coord = null, .normal = null },
        },
    };
    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(mesh));
}

test "single face def vertex + tex coord" {
    var result = try parse(test_allocator, "f 1/4 2/5 3/6");
    defer result.deinit(test_allocator);

    const mesh = Mesh{
        .name = null,
        .num_vertices = &[_]u32{3},
        .indices = &[_]Mesh.Index{
            .{ .vertex = 0, .tex_coord = 3, .normal = null },
            .{ .vertex = 1, .tex_coord = 4, .normal = null },
            .{ .vertex = 2, .tex_coord = 5, .normal = null },
        },
    };
    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(mesh));
}

test "single face def vertex + tex coord + normal" {
    var result = try parse(test_allocator, "f 1/4/7 2/5/8 3/6/9");
    defer result.deinit(test_allocator);

    const mesh = Mesh{
        .name = null,
        .num_vertices = &[_]u32{3},
        .indices = &[_]Mesh.Index{
            .{ .vertex = 0, .tex_coord = 3, .normal = 6 },
            .{ .vertex = 1, .tex_coord = 4, .normal = 7 },
            .{ .vertex = 2, .tex_coord = 5, .normal = 8 },
        },
    };
    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(mesh));
}

test "single face def vertex + normal" {
    var result = try parse(test_allocator, "f 1//7 2//8 3//9");
    defer result.deinit(test_allocator);

    const mesh = Mesh{
        .name = null,
        .num_vertices = &[_]u32{3},
        .indices = &[_]Mesh.Index{
            .{ .vertex = 0, .tex_coord = null, .normal = 6 },
            .{ .vertex = 1, .tex_coord = null, .normal = 7 },
            .{ .vertex = 2, .tex_coord = null, .normal = 8 },
        },
    };
    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(mesh));
}

test "triangle obj exported from blender" {
    const data = @embedFile("../triangle.obj");

    var result = try parse(test_allocator, data);
    defer result.deinit(test_allocator);

    const expected = ObjData{
        .vertices = &[_]f32{
            -1.0, 0.0, 0.0,
            1.0,  0.0, 1.0,
            1.0,  0.0, -1.0,
        },
        .tex_coords = &[_]f32{
            0.0, 0.0,
            1.0, 0.0,
            1.0, 1.0,
        },
        .normals = &[_]f32{ 0.0, 1.0, 0.0 },
        .meshes = &[_]Mesh{
            Mesh{
                .name = "Plane",
                .num_vertices = &[_]u32{3},
                .indices = &[_]Mesh.Index{
                    .{ .vertex = 0, .tex_coord = 0, .normal = 0 },
                    .{ .vertex = 1, .tex_coord = 1, .normal = 0 },
                    .{ .vertex = 2, .tex_coord = 2, .normal = 0 },
                },
            },
        },
    };

    try expectEqualSlices(f32, result.vertices, expected.vertices);
    try expectEqualSlices(f32, result.tex_coords, expected.tex_coords);
    try expectEqualSlices(f32, result.normals, expected.normals);

    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(expected.meshes[0]));
}

test "cube obj exported from blender" {
    const data = @embedFile("../cube.obj");

    var result = try parse(test_allocator, data);
    defer result.deinit(test_allocator);

    const expected = ObjData{
        .vertices = &[_]f32{
            1.0,  1.0,  -1.0,
            1.0,  -1.0, -1.0,
            1.0,  1.0,  1.0,
            1.0,  -1.0, 1.0,
            -1.0, 1.0,  -1.0,
            -1.0, -1.0, -1.0,
            -1.0, 1.0,  1.0,
            -1.0, -1.0, 1.0,
        },
        .tex_coords = &[_]f32{
            0.625, 0.500,
            0.875, 0.500,
            0.875, 0.750,
            0.625, 0.750,
            0.375, 0.750,
            0.625, 1.000,
            0.375, 1.000,
            0.375, 0.000,
            0.625, 0.000,
            0.625, 0.250,
            0.375, 0.250,
            0.125, 0.500,
            0.375, 0.500,
            0.125, 0.750,
        },
        .normals = &[_]f32{
            0.0,  1.0,  0.0,
            0.0,  0.0,  1.0,
            -1.0, 0.0,  0.0,
            0.0,  -1.0, 0.0,
            1.0,  0.0,  0.0,
            0.0,  0.0,  -1.0,
        },
        .meshes = &[_]Mesh{
            Mesh{
                .name = "Cube",
                .num_vertices = &[_]u32{ 4, 4, 4, 4, 4, 4 },
                .indices = &[_]Mesh.Index{
                    .{ .vertex = 0, .tex_coord = 0, .normal = 0 },
                    .{ .vertex = 4, .tex_coord = 1, .normal = 0 },
                    .{ .vertex = 6, .tex_coord = 2, .normal = 0 },
                    .{ .vertex = 2, .tex_coord = 3, .normal = 0 },
                    .{ .vertex = 3, .tex_coord = 4, .normal = 1 },
                    .{ .vertex = 2, .tex_coord = 3, .normal = 1 },
                    .{ .vertex = 6, .tex_coord = 5, .normal = 1 },
                    .{ .vertex = 7, .tex_coord = 6, .normal = 1 },
                    .{ .vertex = 7, .tex_coord = 7, .normal = 2 },
                    .{ .vertex = 6, .tex_coord = 8, .normal = 2 },
                    .{ .vertex = 4, .tex_coord = 9, .normal = 2 },
                    .{ .vertex = 5, .tex_coord = 10, .normal = 2 },
                    .{ .vertex = 5, .tex_coord = 11, .normal = 3 },
                    .{ .vertex = 1, .tex_coord = 12, .normal = 3 },
                    .{ .vertex = 3, .tex_coord = 4, .normal = 3 },
                    .{ .vertex = 7, .tex_coord = 13, .normal = 3 },
                    .{ .vertex = 1, .tex_coord = 12, .normal = 4 },
                    .{ .vertex = 0, .tex_coord = 0, .normal = 4 },
                    .{ .vertex = 2, .tex_coord = 3, .normal = 4 },
                    .{ .vertex = 3, .tex_coord = 4, .normal = 4 },
                    .{ .vertex = 5, .tex_coord = 10, .normal = 5 },
                    .{ .vertex = 4, .tex_coord = 9, .normal = 5 },
                    .{ .vertex = 0, .tex_coord = 0, .normal = 5 },
                    .{ .vertex = 1, .tex_coord = 12, .normal = 5 },
                },
            },
        },
    };

    try expectEqualSlices(f32, result.vertices, expected.vertices);
    try expectEqualSlices(f32, result.tex_coords, expected.tex_coords);
    try expectEqualSlices(f32, result.normals, expected.normals);

    try expect(result.meshes.len == 1);
    try expect(result.meshes[0].eq(expected.meshes[0]));
}

// TODO add test for negative indices
