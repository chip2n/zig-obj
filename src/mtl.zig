const std = @import("std");
const tokenizeAny = std.mem.tokenizeAny;
const Allocator = std.mem.Allocator;

const lineIterator = @import("utils.zig").lineIterator;

pub const MaterialData = struct {
    materials: std.StringHashMapUnmanaged(Material),

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        var iter = self.materials.iterator();
        while (iter.next()) |m| {
            m.value_ptr.deinit(allocator);
            allocator.free(m.key_ptr.*);
        }
        self.materials.deinit(allocator);
    }

    const Builder = struct {
        allocator: Allocator,
        current_material: Material = .{},
        current_name: ?[]const u8 = null,
        materials: std.StringHashMapUnmanaged(Material) = .{},

        fn onError(self: *Builder) void {
            var iter = self.materials.iterator();
            while (iter.next()) |m| {
                m.value_ptr.deinit(self.allocator);
                self.allocator.free(m.key_ptr.*);
            }
            self.materials.deinit(self.allocator);
            if (self.current_name) |n|
                self.allocator.free(n);
        }

        fn finish(self: *Builder) !MaterialData {
            if (self.current_name) |nm|
                try self.materials.put(self.allocator, nm, self.current_material);
            return MaterialData{ .materials = self.materials };
        }

        fn new_material(self: *Builder, name: []const u8) !void {
            if (self.current_name) |n| {
                try self.materials.put(
                    self.allocator,
                    n,
                    self.current_material,
                );
                self.current_material = Material{};
            }
            self.current_name = try self.allocator.dupe(u8, name);
        }
        fn ambient_color(self: *Builder, rgb: [3]f32) !void {
            self.current_material.ambient_color = rgb;
        }
        fn diffuse_color(self: *Builder, rgb: [3]f32) !void {
            self.current_material.diffuse_color = rgb;
        }
        fn specular_color(self: *Builder, rgb: [3]f32) !void {
            self.current_material.specular_color = rgb;
        }
        fn specular_highlight(self: *Builder, v: f32) !void {
            self.current_material.specular_highlight = v;
        }
        fn emissive_coefficient(self: *Builder, rgb: [3]f32) !void {
            self.current_material.emissive_coefficient = rgb;
        }
        fn optical_density(self: *Builder, v: f32) !void {
            self.current_material.optical_density = v;
        }
        fn dissolve(self: *Builder, v: f32) !void {
            self.current_material.dissolve = v;
        }
        fn illumination(self: *Builder, v: u8) !void {
            self.current_material.illumination = v;
        }
        fn bump_map_path(self: *Builder, path: []const u8) !void {
            self.current_material.bump_map_path = try self.allocator.dupe(u8, path);
        }
        fn diffuse_map_path(self: *Builder, path: []const u8) !void {
            self.current_material.diffuse_map_path = try self.allocator.dupe(u8, path);
        }
        fn specular_map_path(self: *Builder, path: []const u8) !void {
            self.current_material.specular_map_path = try self.allocator.dupe(u8, path);
        }
    };
};

// NOTE: I'm not sure which material statements are optional. For now, I'm
// assuming all of them are.
pub const Material = struct {
    ambient_color: ?[3]f32 = null,
    diffuse_color: ?[3]f32 = null,
    specular_color: ?[3]f32 = null,
    specular_highlight: ?f32 = null,
    emissive_coefficient: ?[3]f32 = null,
    optical_density: ?f32 = null,
    dissolve: ?f32 = null,
    illumination: ?u8 = null,

    bump_map_path: ?[]const u8 = null,
    diffuse_map_path: ?[]const u8 = null,
    specular_map_path: ?[]const u8 = null,

    pub fn deinit(self: *Material, allocator: Allocator) void {
        if (self.bump_map_path) |p| allocator.free(p);
        if (self.diffuse_map_path) |p| allocator.free(p);
        if (self.specular_map_path) |p| allocator.free(p);
    }
};

const Keyword = enum {
    comment,
    new_material,
    ambient_color,
    diffuse_color,
    specular_color,
    specular_highlight,
    emissive_coefficient,
    optical_density,
    dissolve,
    illumination,
    bump_map_path,
    diffuse_map_path,
    specular_map_path,
};

pub fn parse(allocator: Allocator, data: []const u8) !MaterialData {
    var b = MaterialData.Builder{ .allocator = allocator };
    errdefer b.onError();
    var fbs = std.io.fixedBufferStream(data);
    return try parseCustom(MaterialData, &b, fbs.reader());
}

pub fn parseCustom(comptime T: type, b: *T.Builder, reader: anytype) !T {
    var buffer: [128]u8 = undefined;
    var lines = lineIterator(reader, &buffer);
    while (try lines.next()) |line| {
        var iter = tokenizeAny(u8, line, " ");
        const def_type =
            if (iter.next()) |tok| try parseKeyword(tok) else continue;
        switch (def_type) {
            .comment => {},
            .new_material => try b.new_material(iter.next().?),
            .ambient_color => try b.ambient_color(try parseVec3(&iter)),
            .diffuse_color => try b.diffuse_color(try parseVec3(&iter)),
            .specular_color => try b.specular_color(try parseVec3(&iter)),
            .specular_highlight => try b.specular_highlight(try parseF32(&iter)),
            .emissive_coefficient => try b.emissive_coefficient(try parseVec3(&iter)),
            .optical_density => try b.optical_density(try parseF32(&iter)),
            .dissolve => try b.dissolve(try parseF32(&iter)),
            .illumination => try b.illumination(try parseU8(&iter)),
            .bump_map_path => try b.bump_map_path(iter.next().?),
            .diffuse_map_path => try b.diffuse_map_path(iter.next().?),
            .specular_map_path => try b.specular_map_path(iter.next().?),
        }
    }
    return try b.finish();
}

fn parseU8(iter: *std.mem.TokenIterator(u8, .any)) !u8 {
    return try std.fmt.parseInt(u8, iter.next().?, 10);
}

fn parseF32(iter: *std.mem.TokenIterator(u8, .any)) !f32 {
    return try std.fmt.parseFloat(f32, iter.next().?);
}

fn parseVec3(iter: *std.mem.TokenIterator(u8, .any)) ![3]f32 {
    const x = try std.fmt.parseFloat(f32, iter.next().?);
    const y = try std.fmt.parseFloat(f32, iter.next().?);
    const z = try std.fmt.parseFloat(f32, iter.next().?);
    return [_]f32{ x, y, z };
}

fn parseKeyword(s: []const u8) !Keyword {
    if (std.mem.eql(u8, s, "#")) {
        return .comment;
    } else if (std.mem.eql(u8, s, "newmtl")) {
        return .new_material;
    } else if (std.mem.eql(u8, s, "Ka")) {
        return .ambient_color;
    } else if (std.mem.eql(u8, s, "Kd")) {
        return .diffuse_color;
    } else if (std.mem.eql(u8, s, "Ks")) {
        return .specular_color;
    } else if (std.mem.eql(u8, s, "Ns")) {
        return .specular_highlight;
    } else if (std.mem.eql(u8, s, "Ke")) {
        return .emissive_coefficient;
    } else if (std.mem.eql(u8, s, "Ni")) {
        return .optical_density;
    } else if (std.mem.eql(u8, s, "d")) {
        return .dissolve;
    } else if (std.mem.eql(u8, s, "illum")) {
        return .illumination;
    } else if (std.mem.eql(u8, s, "map_Bump")) {
        return .bump_map_path;
    } else if (std.mem.eql(u8, s, "map_Kd")) {
        return .diffuse_map_path;
    } else if (std.mem.eql(u8, s, "map_Ns")) {
        return .specular_map_path;
    } else {
        std.log.warn("Unknown keyword: {s}", .{s});
        return error.UnknownKeyword;
    }
}

const test_allocator = std.testing.allocator;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

test "single material" {
    const data = @embedFile("../examples/single.mtl");

    var result = try parse(test_allocator, data);
    defer result.deinit(test_allocator);

    const material = result.materials.get("Material").?;
    try expectEqualSlices(f32, &material.ambient_color.?, &.{ 1.0, 1.0, 1.0 });
    try expectEqualSlices(f32, &material.diffuse_color.?, &.{ 0.9, 0.9, 0.9 });
    try expectEqualSlices(f32, &material.specular_color.?, &.{ 0.8, 0.8, 0.8 });
    try expectEqualSlices(f32, &material.emissive_coefficient.?, &.{ 0.7, 0.7, 0.7 });
    try expectEqual(material.specular_highlight.?, 225.0);
    try expectEqual(material.optical_density.?, 1.45);
    try expectEqual(material.dissolve.?, 1.0);
    try expectEqual(material.illumination.?, 2);
    try expectEqualStrings(material.bump_map_path.?, "/path/to/bump.png");
    try expectEqualStrings(material.diffuse_map_path.?, "/path/to/diffuse.png");
    try expectEqualStrings(material.specular_map_path.?, "/path/to/specular.png");
}

test "windows line endings" {
    const data = @embedFile("../examples/triangle_windows.mtl");

    var result = try parse(test_allocator, data);
    defer result.deinit(test_allocator);

    const material = result.materials.get("None").?;
    try expectEqualSlices(f32, &material.ambient_color.?, &.{ 0.8, 0.8, 0.8 });
    try expectEqualSlices(f32, &material.diffuse_color.?, &.{ 0.8, 0.8, 0.8 });
    try expectEqualSlices(f32, &material.specular_color.?, &.{ 0.8, 0.8, 0.8 });
    try expectEqual(material.dissolve.?, 1.0);
    try expectEqual(material.illumination.?, 2);
}

test "empty mtl" {
    const data = @embedFile("../examples/empty.mtl");

    var result = try parse(test_allocator, data);
    defer result.deinit(test_allocator);

    try expectEqual(result.materials.size, 0);
}
