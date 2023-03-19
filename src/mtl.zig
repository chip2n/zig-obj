const std = @import("std");

const parseFloat = std.fmt.parseFloat;
const parseInt = std.fmt.parseInt;

pub const MaterialData = struct {
    materials: std.StringHashMapUnmanaged(Material),

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.materials.deinit(allocator);
    }
};

// NOTE: I'm not sure which material statements are optional. For now, I'm assuming all of them are.
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

pub fn parse(allocator: std.mem.Allocator, data: []const u8) !MaterialData {
    var materials = std.StringHashMapUnmanaged(Material){};

    var lines = std.mem.tokenize(u8, data, "\r\n");
    var current_material = Material{};
    var name: ?[]const u8 = null;

    while (lines.next()) |line| {
        var words = std.mem.tokenize(u8, line, " ");
        const keyword = try parseKeyword(words.next().?);

        switch (keyword) {
            .comment => {},
            .new_material => {
                if (name) |n| {
                    try materials.put(allocator, n, current_material);
                    current_material = Material{};
                }
                name = words.next().?;
            },
            .ambient_color => {
                current_material.ambient_color = try parseVec3(&words);
            },
            .diffuse_color => {
                current_material.diffuse_color = try parseVec3(&words);
            },
            .specular_color => {
                current_material.specular_color = try parseVec3(&words);
            },
            .specular_highlight => {
                current_material.specular_highlight = try parseFloat(f32, words.next().?);
            },
            .emissive_coefficient => {
                current_material.emissive_coefficient = try parseVec3(&words);
            },
            .optical_density => {
                current_material.optical_density = try parseFloat(f32, words.next().?);
            },
            .dissolve => {
                current_material.dissolve = try parseFloat(f32, words.next().?);
            },
            .illumination => {
                current_material.illumination = try parseInt(u8, words.next().?, 10);
            },
            .bump_map_path => {
                current_material.bump_map_path = words.next().?;
            },
            .diffuse_map_path => {
                current_material.diffuse_map_path = words.next().?;
            },
            .specular_map_path => {
                current_material.specular_map_path = words.next().?;
            },
        }
    }

    if (name) |n| {
        try materials.put(allocator, n, current_material);
    }

    return MaterialData{ .materials = materials };
}

fn parseVec3(iter: *std.mem.TokenIterator(u8)) ![3]f32 {
    const x = try parseFloat(f32, iter.next().?);
    const y = try parseFloat(f32, iter.next().?);
    const z = try parseFloat(f32, iter.next().?);
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
