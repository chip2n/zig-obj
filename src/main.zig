const std = @import("std");
const tokenize = std.mem.tokenize;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const ObjData = struct {
    vertices: []const Vector4,
    tex_coords: []const Vector3,
    normals: []const Vector3,

    fn eq(self: ObjData, other: ObjData) bool {
        if (self.vertices.len != other.vertices.len) return false;
        if (self.tex_coords.len != other.tex_coords.len) return false;
        if (self.normals.len != other.normals.len) return false;

        for (self.vertices) |vertex, i| {
            if (!vertex.eq(other.vertices[i])) return false;
        }

        for (self.tex_coords) |coord, i| {
            if (!coord.eq(other.tex_coords[i])) return false;
        }

        for (self.normals) |normal, i| {
            if (!normal.eq(other.normals[i])) return false;
        }

        return true;
    }

    fn deinit(self: ObjData, allocator: *Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.tex_coords);
        allocator.free(self.normals);
    }
};

const Vector3 = struct {
    x: f32,
    y: f32,
    z: f32,

    fn eq(self: Vector3, other: Vector3) bool {
        return self.x == other.x and
            self.y == other.y and
            self.z == other.z;
    }
};

const Vector4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    fn eq(self: Vector4, other: Vector4) bool {
        return self.x == other.x and
            self.y == other.y and
            self.z == other.z and
            self.w == other.w;
    }
};

const Face = struct {
    vertex_indices: []usize,
};

const DefType = enum {
    Vertex,
    TexCoord,
    Normal,
};

fn parse(allocator: *Allocator, data: []const u8) !ObjData {
    var vertices = ArrayList(Vector4).init(allocator);
    errdefer vertices.deinit();

    var tex_coords = ArrayList(Vector3).init(allocator);
    errdefer tex_coords.deinit();

    var normals = ArrayList(Vector3).init(allocator);
    errdefer normals.deinit();

    var lines = tokenize(data, "\n");
    while (lines.next()) |line| {
        var iter = tokenize(line, " ");
        const def_type = try parse_type(iter.next().?);
        switch (def_type) {
            DefType.Vertex => {
                const x = try std.fmt.parseFloat(f32, iter.next().?);
                const y = try std.fmt.parseFloat(f32, iter.next().?);
                const z = try std.fmt.parseFloat(f32, iter.next().?);
                const w = if (iter.next()) |n| try std.fmt.parseFloat(f32, n) else 1.0;

                try vertices.append(Vector4{ .x = x, .y = y, .z = z, .w = w });
            },
            DefType.TexCoord => {
                const u = try std.fmt.parseFloat(f32, iter.next().?);
                const v = try std.fmt.parseFloat(f32, iter.next().?);
                const w = if (iter.next()) |n| try std.fmt.parseFloat(f32, n) else 0.0;

                try tex_coords.append(Vector3{ .x = u, .y = v, .z = w });
            },
            DefType.Normal => {
                const x = try std.fmt.parseFloat(f32, iter.next().?);
                const y = try std.fmt.parseFloat(f32, iter.next().?);
                const z = try std.fmt.parseFloat(f32, iter.next().?);

                try normals.append(Vector3{ .x = x, .y = y, .z = z });
            },
        }
    }

    return ObjData{
        .vertices = vertices.toOwnedSlice(),
        .tex_coords = tex_coords.toOwnedSlice(),
        .normals = normals.toOwnedSlice(),
    };
}

fn parse_type(t: []const u8) !DefType {
    if (std.mem.eql(u8, t, "v")) {
        return DefType.Vertex;
    } else if (std.mem.eql(u8, t, "vt")) {
        return DefType.TexCoord;
    } else if (std.mem.eql(u8, t, "vn")) {
        return DefType.Normal;
    } else {
        return error.UnknownDefType;
    }
}

// ------------------------------------------------------------------------------

fn test_field(comptime field: []const u8, data: []const u8, value: anytype) !void {
    const allocator = std.testing.allocator;
    var result = try parse(allocator, data);
    defer result.deinit(allocator);

    var expected = ObjData{
        .vertices = &[_]Vector4{},
        .tex_coords = &[_]Vector3{},
        .normals = &[_]Vector3{},
    };
    @field(expected, field) = &[_]@TypeOf(value){value};

    expect(expected.eq(result));
}

test "unknown def" {
    const allocator = std.testing.allocator;
    expectError(error.UnknownDefType, parse(allocator, "invalid 0 1 2"));
}

test "vertex def xyz" {
    try test_field("vertices", "v 0.123 0.234 0.345", Vector4{ .x = 0.123, .y = 0.234, .z = 0.345, .w = 1.0 });
}

test "vertex def xyzw" {
    try test_field("vertices", "v 0.123 0.234 0.345 0.456", Vector4{ .x = 0.123, .y = 0.234, .z = 0.345, .w = 0.456 });
}

test "tex coord def uv" {
    try test_field("tex_coords", "vt 0.123 0.234", Vector3{ .x = 0.123, .y = 0.234, .z = 0.0 });
}

test "tex coord def uvw" {
    try test_field("tex_coords", "vt 0.123 0.234 0.345", Vector3{ .x = 0.123, .y = 0.234, .z = 0.345 });
}

test "normal def xyz" {
    try test_field("normals", "vn 0.123 0.234 0.345", Vector3{ .x = 0.123, .y = 0.234, .z = 0.345 });
}
