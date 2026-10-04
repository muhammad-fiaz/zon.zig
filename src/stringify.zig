//! Stringify - Converts Value trees to ZON source code.
//!
//! This module serializes the intermediate Value tree back to ZON format.
//! Unlike `std.zon.Serializer` which serializes typed Zig values directly,
//! this module works with the document-based Value representation.
//!
//! See also: https://codeberg.org/ziglang/zig/src/branch/master/lib/std/zon/Serializer.zig

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const utils = @import("utils.zig");

/// Stringification options.
pub const StringifyOptions = struct {
    indent: usize = 4,
    initialIndent: usize = 0,
    quoteKeys: bool = false,
    sortKeys: bool = true,
};

pub const StringifyError = Allocator.Error;

pub const Buffer = struct {
    allocator: Allocator,
    data: std.ArrayList(u8),

    pub fn init(allocator: Allocator) Buffer {
        return .{
            .allocator = allocator,
            .data = .empty,
        };
    }

    pub fn deinit(self: *Buffer) void {
        self.data.deinit(self.allocator);
    }

    pub fn append(self: *Buffer, char: u8) StringifyError!void {
        try self.data.append(self.allocator, char);
    }

    pub fn appendSlice(self: *Buffer, slice: []const u8) StringifyError!void {
        try self.data.appendSlice(self.allocator, slice);
    }

    pub fn appendNTimes(self: *Buffer, char: u8, count: usize) StringifyError!void {
        try self.data.appendNTimes(self.allocator, char, count);
    }

    pub fn toOwnedSlice(self: *Buffer) StringifyError![]u8 {
        return self.data.toOwnedSlice(self.allocator);
    }
};

pub fn stringify(allocator: Allocator, value: *const Value, options: StringifyOptions) StringifyError![]u8 {
    var buffer = Buffer.init(allocator);
    errdefer buffer.deinit();

    try stringifyValue(&buffer, value, options.initialIndent, options.indent, options.quoteKeys, options.sortKeys);

    return buffer.toOwnedSlice();
}

/// Converts a Value to a JSON string. Caller must free.
pub fn stringifyJson(allocator: Allocator, value: *const Value) StringifyError![]u8 {
    var buffer = Buffer.init(allocator);
    errdefer buffer.deinit();

    try stringifyValueJson(&buffer, value);

    return buffer.toOwnedSlice();
}

/// Write a value to `path` atomically: stringify into a temp file then rename.
pub fn writeToFileAtomic(allocator: Allocator, value: *const Value, path: []const u8, options: StringifyOptions) StringifyError!void {
    const output = try stringify(allocator, value, options);
    defer allocator.free(output);

    const tmpPath = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmpPath);

    const file = try utils.fs.createFile(tmpPath, .{});
    defer utils.fs.closeFile(file);

    try utils.fs.writeFile(file, output);
    try utils.fs.writeFile(file, "\n");

    try utils.fs.rename(tmpPath, path);
}

fn stringifyValue(buffer: *Buffer, value: *const Value, indent: usize, indentSize: usize, quoteKeys: bool, sortKeys: bool) StringifyError!void {
    switch (value.*) {
        .nullVal => try buffer.appendSlice("null"),
        .boolVal => |b| try buffer.appendSlice(if (b) "true" else "false"),
        .number => |n| switch (n) {
            .int => |i| {
                var numBuf: [32]u8 = undefined;
                const slice = std.fmt.bufPrint(&numBuf, "{d}", .{i}) catch unreachable;
                try buffer.appendSlice(slice);
            },
            .float => |f| {
                if (std.math.isPositiveInf(f)) {
                    try buffer.appendSlice("inf");
                } else if (std.math.isNegativeInf(f)) {
                    try buffer.appendSlice("-inf");
                } else if (std.math.isNan(f)) {
                    try buffer.appendSlice("nan");
                } else {
                    var numBuf: [64]u8 = undefined;
                    const slice = std.fmt.bufPrint(&numBuf, "{d}", .{f}) catch unreachable;
                    try buffer.appendSlice(slice);
                }
            },
        },
        .string => |s| try stringifyString(buffer, s),
        .identifier => |s| try stringifyIdentifier(buffer, s),
        .object => |o| try stringifyObject(buffer, &o, indent, indentSize, quoteKeys, sortKeys),
        .array => |a| try stringifyArray(buffer, &a, indent, indentSize, quoteKeys, sortKeys),
    }
}

fn stringifyIdentifier(buffer: *Buffer, s: []const u8) StringifyError!void {
    try buffer.append('.');
    try buffer.appendSlice(s);
}

fn stringifyString(buffer: *Buffer, s: []const u8) StringifyError!void {
    try buffer.append('"');
    for (s) |c| {
        switch (c) {
            '\n' => try buffer.appendSlice("\\n"),
            '\r' => try buffer.appendSlice("\\r"),
            '\t' => try buffer.appendSlice("\\t"),
            '\\' => try buffer.appendSlice("\\\\"),
            '"' => try buffer.appendSlice("\\\""),
            else => try buffer.append(c),
        }
    }
    try buffer.append('"');
}

fn stringifyObject(buffer: *Buffer, obj: *const Value.Object, indent: usize, indentSize: usize, quoteKeys: bool, sortKeys: bool) StringifyError!void {
    if (obj.count() == 0) {
        try buffer.appendSlice(".{}");
        return;
    }

    try buffer.appendSlice(".{\n");

    const keys = try obj.keys(buffer.allocator);
    defer buffer.allocator.free(keys);

    if (sortKeys) {
        std.mem.sort([]const u8, keys, {}, utils.stringLessThan);
    }

    for (keys) |key| {
        const valPtr = obj.entries.getPtr(key).?;

        try appendIndent(buffer, indent + indentSize);
        try buffer.append('.');
        if (quoteKeys or !utils.isValidIdentifier(key)) {
            try stringifyString(buffer, key); // Writes "key"
        } else {
            try buffer.appendSlice(key);
        }
        try buffer.appendSlice(" = ");
        try stringifyValue(buffer, valPtr, indent + indentSize, indentSize, quoteKeys, sortKeys);
        try buffer.appendSlice(",\n");
    }

    try appendIndent(buffer, indent);
    try buffer.append('}');
}

fn stringifyValueJson(buffer: *Buffer, value: *const Value) StringifyError!void {
    switch (value.*) {
        .nullVal => try buffer.appendSlice("null"),
        .boolVal => |b| try buffer.appendSlice(if (b) "true" else "false"),
        .number => |n| switch (n) {
            .int => |i| {
                var numBuf: [32]u8 = undefined;
                const slice = std.fmt.bufPrint(&numBuf, "{d}", .{i}) catch unreachable;
                try buffer.appendSlice(slice);
            },
            .float => |f| {
                if (std.math.isPositiveInf(f)) {
                    try buffer.appendSlice("null");
                } else if (std.math.isNegativeInf(f)) {
                    try buffer.appendSlice("null");
                } else if (std.math.isNan(f)) {
                    try buffer.appendSlice("null");
                } else {
                    var numBuf: [64]u8 = undefined;
                    const slice = std.fmt.bufPrint(&numBuf, "{d}", .{f}) catch unreachable;
                    try buffer.appendSlice(slice);
                }
            },
        },
        .string => |s| try stringifyString(buffer, s),
        .identifier => |s| try stringifyString(buffer, s),
        .object => |o| {
            try buffer.append('{');
            var it = o.entries.iterator();
            var first = true;
            while (it.next()) |entry| {
                if (!first) try buffer.appendSlice(", ");
                first = false;
                try stringifyString(buffer, entry.key_ptr.*);
                try buffer.append(':');
                try stringifyValueJson(buffer, entry.value_ptr);
            }
            try buffer.append('}');
        },
        .array => |a| {
            try buffer.append('[');
            for (a.items.items, 0..) |*item, i| {
                if (i > 0) try buffer.appendSlice(", ");
                try stringifyValueJson(buffer, item);
            }
            try buffer.append(']');
        },
    }
}

fn stringifyArray(buffer: *Buffer, arr: *const Value.Array, indent: usize, indentSize: usize, quoteKeys: bool, sortKeys: bool) StringifyError!void {
    if (arr.len() == 0) {
        try buffer.appendSlice(".{}");
        return;
    }

    try buffer.appendSlice(".{\n");

    for (arr.items.items) |*item| {
        try appendIndent(buffer, indent + indentSize);
        try stringifyValue(buffer, item, indent + indentSize, indentSize, quoteKeys, sortKeys);
        try buffer.appendSlice(",\n");
    }

    try appendIndent(buffer, indent);
    try buffer.append('}');
}

fn appendIndent(buffer: *Buffer, count: usize) StringifyError!void {
    try buffer.appendNTimes(' ', count);
}

test "stringify: null" {
    const allocator = std.testing.allocator;
    var val: Value = .nullVal;
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("null", result);
}

test "stringify: bool true" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .boolVal = true };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("true", result);
}

test "stringify: bool false" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .boolVal = false };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("false", result);
}

test "stringify: int" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .number = .{ .int = 42 } };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("42", result);
}

test "stringify: float" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .number = .{ .float = 3.14 } };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expect(std.mem.indexOf(u8, result, "3.14") != null);
}

test "stringify: string" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .string = "hello" };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("\"hello\"", result);
}

test "stringify: identifier" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .identifier = "my_package" };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings(".my_package", result);
}

test "stringify: string with escapes" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .string = "hello\nworld" };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("\"hello\\nworld\"", result);
}

test "stringify: empty object" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .object = Value.Object.init(allocator) };
    defer val.deinit(allocator);
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings(".{}", result);
}

test "stringify: empty array" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .array = Value.Array.init(allocator) };
    defer val.deinit(allocator);
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings(".{}", result);
}

test "stringify: object with value" {
    const allocator = std.testing.allocator;
    var obj = Value.Object.init(allocator);
    try obj.put("name", .{ .string = try allocator.dupe(u8, "test") });
    var val: Value = .{ .object = obj };
    defer val.deinit(allocator);

    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, ".name") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\"test\"") != null);
}

test "stringify: compact output" {
    const allocator = std.testing.allocator;
    var obj = Value.Object.init(allocator);
    try obj.put("a", .{ .boolVal = true });
    var val: Value = .{ .object = obj };
    defer val.deinit(allocator);

    const result = try stringify(allocator, &val, .{ .indent = 0 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "    ") == null);
}

test "stringify: sortKeys respects ordering" {
    const allocator = std.testing.allocator;

    // Insert keys z, a, y - with sortKeys=true (default), output should be a, y, z
    var obj = Value.Object.init(allocator);
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });
    // We need to put keys in reverse order to observe the sort effect
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("y", .{ .string = try allocator.dupe(u8, "middle") });
    var val: Value = .{ .object = obj };
    defer val.deinit(allocator);

    // With sortKeys=true (default), keys should appear in sorted order
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, ".a = \"first\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, ".y = \"middle\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, ".z = \"last\"") != null);

    // .a should appear before .y which should appear before .z in sorted output
    const aPos = std.mem.indexOf(u8, result, ".a").?;
    const yPos = std.mem.indexOf(u8, result, ".y").?;
    const zPos = std.mem.indexOf(u8, result, ".z").?;
    try std.testing.expect(aPos < yPos);
    try std.testing.expect(yPos < zPos);
}
