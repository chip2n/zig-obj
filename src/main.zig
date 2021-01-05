const std = @import("std");
const tokenize = std.mem.tokenize;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const parseFloat = std.fmt.parseFloat;
const parseUnsigned = std.fmt.parseUnsigned;

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const ObjData = struct {
    vertices: []const f32,
    tex_coords: []const f32,
    normals: []const f32,

    meshes: []const Mesh,

    fn eq(self: ObjData, other: ObjData) bool {
        if (!std.mem.eql(f32, self.vertices, other.vertices)) return false;
        if (!std.mem.eql(f32, self.tex_coords, other.tex_coords)) return false;
        if (!std.mem.eql(f32, self.normals, other.normals)) return false;
        return true;
    }

    fn deinit(self: ObjData, allocator: *Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.tex_coords);
        allocator.free(self.normals);

        for (self.meshes) |mesh| mesh.deinit(allocator);
        allocator.free(self.meshes);
    }
};

const Index = struct {
    vertex: ?u32,
    tex_coord: ?u32,
    normal: ?u32,
};

const Mesh = struct {
    num_vertices: []const u32,
    indices: []const Index,

    fn deinit(self: Mesh, allocator: *Allocator) void {
        allocator.free(self.num_vertices);
        allocator.free(self.indices);
    }
};

const DefType = enum {
    Comment,
    Vertex,
    TexCoord,
    Normal,
    Face,
};

fn parse(allocator: *Allocator, data: []const u8) !ObjData {
    var vertices = ArrayList(f32).init(allocator);
    errdefer vertices.deinit();

    var tex_coords = ArrayList(f32).init(allocator);
    errdefer tex_coords.deinit();

    var normals = ArrayList(f32).init(allocator);
    errdefer normals.deinit();

    var meshes = ArrayList(Mesh).init(allocator);
    errdefer meshes.deinit();

    // current mesh
    var num_verts = ArrayList(u32).init(allocator);
    errdefer num_verts.deinit();
    var indices = ArrayList(Index).init(allocator);
    errdefer indices.deinit();

    var lines = tokenize(data, "\n");
    while (lines.next()) |line| {
        var iter = tokenize(line, " ");
        const def_type = try parse_type(iter.next().?);
        switch (def_type) {
            DefType.Comment => {
                // ignore
            },
            DefType.Vertex => {
                try vertices.append(try parseFloat(f32, iter.next().?));
                try vertices.append(try parseFloat(f32, iter.next().?));
                try vertices.append(try parseFloat(f32, iter.next().?));
            },
            DefType.TexCoord => {
                try tex_coords.append(try parseFloat(f32, iter.next().?));
                try tex_coords.append(try parseFloat(f32, iter.next().?));
            },
            DefType.Normal => {
                try normals.append(try parseFloat(f32, iter.next().?));
                try normals.append(try parseFloat(f32, iter.next().?));
                try normals.append(try parseFloat(f32, iter.next().?));
            },
            DefType.Face => {
                var i: u32 = 0;
                while (iter.next()) |entry| {
                    var entry_iter = tokenize(entry, "/");
                    // TODO support x//y and similar
                    // NOTE obj is one-indexed - let's make it zero-indexed
                    try indices.append(Index{
                        .vertex = if (entry_iter.next()) |e| (try parseUnsigned(u32, e, 10)) - 1 else null,
                        .tex_coord = if (entry_iter.next()) |e| (try parseUnsigned(u32, e, 10)) - 1 else null,
                        .normal = if (entry_iter.next()) |e| (try parseUnsigned(u32, e, 10)) - 1 else null,
                    });

                    i += 1;
                }
                try num_verts.append(i);
            },
        }
    }

    // TODO support multiple meshes
    try meshes.append(Mesh{
        .num_vertices = num_verts.toOwnedSlice(),
        .indices = indices.toOwnedSlice(),
    });

    return ObjData{
        .vertices = vertices.toOwnedSlice(),
        .tex_coords = tex_coords.toOwnedSlice(),
        .normals = normals.toOwnedSlice(),
        .meshes = meshes.toOwnedSlice(),
    };
}

fn parse_type(t: []const u8) !DefType {
    if (std.mem.eql(u8, t, "#")) {
        return DefType.Comment;
    } else if (std.mem.eql(u8, t, "v")) {
        return DefType.Vertex;
    } else if (std.mem.eql(u8, t, "vt")) {
        return DefType.TexCoord;
    } else if (std.mem.eql(u8, t, "vn")) {
        return DefType.Normal;
    } else if (std.mem.eql(u8, t, "f")) {
        return DefType.Face;
    } else {
        return error.UnknownDefType;
    }
}

// ------------------------------------------------------------------------------

fn test_single_field(comptime field: []const u8, data: []const u8, value: anytype) !void {
    const allocator = std.testing.allocator;
    var result = try parse(allocator, data);
    defer result.deinit(allocator);

    var expected = ObjData{
        .vertices = &[_]f32{},
        .tex_coords = &[_]f32{},
        .normals = &[_]f32{},
        .meshes = &[_]Mesh{},
    };
    @field(expected, field) = value;

    expect(expected.eq(result));
}

test "unknown def" {
    const allocator = std.testing.allocator;
    expectError(error.UnknownDefType, parse(allocator, "invalid 0 1 2"));
}

test "comment" {
    const allocator = std.testing.allocator;
    const result = try parse(allocator, "# this is a comment");
    defer result.deinit(allocator);
    expect(result.vertices.len == 0);
    expect(result.tex_coords.len == 0);
    expect(result.normals.len == 0);
}

test "vertex def xyz" {
    try test_single_field("vertices", "v 0.123 0.234 0.345", &[_]f32{ 0.123, 0.234, 0.345 });
}

test "vertex def xyzw" {
    try test_single_field("vertices", "v 0.123 0.234 0.345 0.456", &[_]f32{ 0.123, 0.234, 0.345 });
}

test "tex coord def uv" {
    try test_single_field("tex_coords", "vt 0.123 0.234", &[_]f32{ 0.123, 0.234 });
}

test "tex coord def uvw" {
    try test_single_field("tex_coords", "vt 0.123 0.234 0.345", &[_]f32{ 0.123, 0.234 });
}

test "normal def xyz" {
    try test_single_field("normals", "vn 0.123 0.234 0.345", &[_]f32{ 0.123, 0.234, 0.345 });
}

test "face def vertex only" {
    try test_single_field("meshes", "f 1 2 3", &[_]Mesh{
        Mesh{
            .num_vertices = &[_]u32{3},
            .indices = &[_]Index{
                Index{ .vertex = 0, .tex_coord = null, .normal = null },
                Index{ .vertex = 1, .tex_coord = null, .normal = null },
                Index{ .vertex = 2, .tex_coord = null, .normal = null },
            },
        },
    });
}
