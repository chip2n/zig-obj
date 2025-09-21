const std = @import("std");

pub fn LineIterator(comptime Reader: type) type {
    return struct {
        buffer: []u8,
        reader: Reader,

        pub fn next(self: *@This()) !?[]const u8 {
            var fbs = std.Io.Writer.fixed(self.buffer);
            const written = self.reader.streamDelimiter(&fbs, '\n') catch |err| switch (err) {
                error.EndOfStream => if (fbs.end == 0) return null else fbs.end,
                else => |e| return e,
            };
            _ = self.reader.discardDelimiterInclusive('\n') catch {};
            var line = fbs.buffer[0..written];
            if (0 < line.len and line[line.len - 1] == '\r') {
                line = line[0 .. line.len - 1];
            }
            return line;
        }
    };
}

pub fn lineIterator(rdr: anytype, buffer: []u8) LineIterator(@TypeOf(rdr)) {
    return .{ .buffer = buffer, .reader = rdr };
}
