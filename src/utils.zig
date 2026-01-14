//! Internal utilities for zon.zig

const std = @import("std");
const Allocator = std.mem.Allocator;

/// Duplicates a string using the provided allocator.
pub fn dupeString(allocator: Allocator, str: []const u8) ![]u8 {
    return allocator.dupe(u8, str);
}

/// Splits a dot-separated path into segments. Caller must free the result.
pub fn splitPath(allocator: Allocator, path: []const u8) ![][]const u8 {
    var parts_iter = std.mem.splitScalar(u8, path, '.');
    var count_val: usize = 0;

    var iter_copy = parts_iter;
    while (iter_copy.next()) |_| {
        count_val += 1;
    }

    const parts = try allocator.alloc([]const u8, count_val);
    var i: usize = 0;
    while (parts_iter.next()) |part| {
        parts[i] = part;
        i += 1;
    }

    return parts;
}

/// Joins path segments with dots. Caller must free the result.
pub fn joinPath(allocator: Allocator, parts: []const []const u8) ![]u8 {
    return std.mem.join(allocator, ".", parts);
}

/// Checks if a string is a simple valid identifier (alphanumeric/underscore).
/// Does not check for keywords.
pub fn isValidIdentifier(s: []const u8) bool {
    if (s.len == 0) return false;
    for (s, 0..) |c, i| {
        switch (c) {
            'a'...'z', 'A'...'Z', '_' => {},
            '0'...'9' => if (i == 0) return false,
            else => return false,
        }
    }
    return true;
}
