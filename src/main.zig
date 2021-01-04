const std = @import("std");
const tokenize = std.mem.tokenize;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const ObjData = struct {
    vertices: []const Vertex,
    tex_coords: []const TexCoord,

    fn eq(self: ObjData, other: ObjData) bool {
        if (self.vertices.len != other.vertices.len) return false;
        if (self.tex_coords.len != other.tex_coords.len) return false;

        for (self.vertices) |vertex, i| {
            if (!vertex.eq(other.vertices[i])) return false;
        }

        for (self.tex_coords) |coord, i| {
            if (!coord.eq(other.tex_coords[i])) return false;
        }

        return true;
    }

    fn deinit(self: ObjData, allocator: *Allocator) void {
        allocator.free(self.vertices);
        allocator.free(self.tex_coords);
    }
};

const Vertex = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    fn eq(self: Vertex, other: Vertex) bool {
        return self.x == other.x and
            self.y == other.y and
            self.z == other.z and
            self.w == other.w;
    }
};

const TexCoord = struct {
    u: f32,
    v: f32,
    w: f32,

    fn eq(self: TexCoord, other: TexCoord) bool {
        return self.u == other.u and
            self.v == other.v and
            self.w == other.w;
    }
};

const Normal = struct { x: f32, y: f32, z: f32 };
const Face = struct {
    vertex_indices: []usize,
};

const DefType = enum {
    Vertex,
    TexCoords,
};

fn parse(allocator: *Allocator, data: []const u8) !ObjData {
    var vertices = ArrayList(Vertex).init(allocator);
    errdefer vertices.deinit();

    var tex_coords = ArrayList(TexCoord).init(allocator);
    errdefer tex_coords.deinit();

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

                try vertices.append(Vertex{ .x = x, .y = y, .z = z, .w = w });
            },
            DefType.TexCoords => {
                const u = try std.fmt.parseFloat(f32, iter.next().?);
                const v = try std.fmt.parseFloat(f32, iter.next().?);
                const w = if (iter.next()) |n| try std.fmt.parseFloat(f32, n) else 0.0;

                try tex_coords.append(TexCoord{ .u = u, .v = v, .w = w });
            },
        }
    }

    return ObjData{
        .vertices = vertices.toOwnedSlice(),
        .tex_coords = tex_coords.toOwnedSlice(),
    };
}

fn parse_type(t: []const u8) !DefType {
    if (std.mem.eql(u8, t, "v")) {
        return DefType.Vertex;
    } else if (std.mem.eql(u8, t, "vt")) {
        return DefType.TexCoords;
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
        .vertices = &[_]Vertex{},
        .tex_coords = &[_]TexCoord{},
    };
    @field(expected, field) = &[_]@TypeOf(value){value};

    expect(expected.eq(result));
}

test "unknown def" {
    const allocator = std.testing.allocator;
    expectError(error.UnknownDefType, parse(allocator, "invalid 0 1 2"));
}

test "vertex def xyz" {
    try test_field("vertices", "v 0.123 0.234 0.345", Vertex{ .x = 0.123, .y = 0.234, .z = 0.345, .w = 1.0 });
}

test "vertex def xyzw" {
    try test_field("vertices", "v 0.123 0.234 0.345 0.456", Vertex{ .x = 0.123, .y = 0.234, .z = 0.345, .w = 0.456 });
}

test "tex coord def uv" {
    try test_field("tex_coords", "vt 0.123 0.234", TexCoord{ .u = 0.123, .v = 0.234, .w = 0.0 });
}

test "tex coord def uvw" {
    try test_field("tex_coords", "vt 0.123 0.234 0.345", TexCoord{ .u = 0.123, .v = 0.234, .w = 0.345 });
}
