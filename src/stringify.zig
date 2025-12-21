//! Stringify - Converts Value trees to ZON source code.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;

/// Stringification options.
pub const StringifyOptions = struct {
    indent: usize = 4,
    initial_indent: usize = 0,
};

pub const StringifyError = Allocator.Error;

pub const Buffer = struct {
    allocator: Allocator,
    data: std.ArrayListUnmanaged(u8),

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

/// Converts a Value to a ZON string. Caller must free.
pub fn stringify(allocator: Allocator, value: *const Value, options: StringifyOptions) StringifyError![]u8 {
    var buffer = Buffer.init(allocator);
    errdefer buffer.deinit();

    try stringifyValue(&buffer, value, options.initial_indent, options.indent);

    return buffer.toOwnedSlice();
}

/// Write a value to `path` atomically: stringify into a temp file then rename.
pub fn writeToFileAtomic(allocator: Allocator, value: *const Value, path: []const u8, options: StringifyOptions) StringifyError!void {
    const output = try stringify(allocator, value, options);
    defer allocator.free(output);

    const tmp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp_path);

    const file = try std.fs.cwd().createFile(tmp_path, .{});
    defer file.close();

    try file.writeAll(output);
    try file.writeAll("\n");

    try std.fs.cwd().rename(tmp_path, path);
}

fn stringifyValue(buffer: *Buffer, value: *const Value, indent: usize, indent_size: usize) StringifyError!void {
    switch (value.*) {
        .null_val => try buffer.appendSlice("null"),
        .bool_val => |b| try buffer.appendSlice(if (b) "true" else "false"),
        .number => |n| switch (n) {
            .int => |i| {
                var num_buf: [32]u8 = undefined;
                const slice = std.fmt.bufPrint(&num_buf, "{d}", .{i}) catch unreachable;
                try buffer.appendSlice(slice);
            },
            .float => |f| {
                var num_buf: [64]u8 = undefined;
                const slice = std.fmt.bufPrint(&num_buf, "{d}", .{f}) catch unreachable;
                try buffer.appendSlice(slice);
            },
        },
        .string => |s| try stringifyString(buffer, s),
        .identifier => |s| try stringifyIdentifier(buffer, s),
        .object => |o| try stringifyObject(buffer, &o, indent, indent_size),
        .array => |a| try stringifyArray(buffer, &a, indent, indent_size),
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

fn stringifyObject(buffer: *Buffer, obj: *const Value.Object, indent: usize, indent_size: usize) StringifyError!void {
    if (obj.count() == 0) {
        try buffer.appendSlice(".{}");
        return;
    }

    try buffer.appendSlice(".{\n");

    const keys = try obj.keys(buffer.allocator);
    defer buffer.allocator.free(keys);

    std.mem.sort([]const u8, keys, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    for (keys) |key| {
        const val_ptr = obj.entries.getPtr(key).?;

        try appendIndent(buffer, indent + indent_size);
        try buffer.append('.');
        try buffer.appendSlice(key);
        try buffer.appendSlice(" = ");
        try stringifyValue(buffer, val_ptr, indent + indent_size, indent_size);
        try buffer.appendSlice(",\n");
    }

    try appendIndent(buffer, indent);
    try buffer.append('}');
}

fn stringifyArray(buffer: *Buffer, arr: *const Value.Array, indent: usize, indent_size: usize) StringifyError!void {
    if (arr.len() == 0) {
        try buffer.appendSlice(".{}");
        return;
    }

    try buffer.appendSlice(".{\n");

    for (arr.items.items) |*item| {
        try appendIndent(buffer, indent + indent_size);
        try stringifyValue(buffer, item, indent + indent_size, indent_size);
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
    var val: Value = .null_val;
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("null", result);
}

test "stringify: bool true" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .bool_val = true };
    const result = try stringify(allocator, &val, .{});
    defer allocator.free(result);
    try std.testing.expectEqualStrings("true", result);
}

test "stringify: bool false" {
    const allocator = std.testing.allocator;
    var val: Value = .{ .bool_val = false };
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
    try obj.put("a", .{ .bool_val = true });
    var val: Value = .{ .object = obj };
    defer val.deinit(allocator);

    const result = try stringify(allocator, &val, .{ .indent = 0 });
    defer allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "    ") == null);
}
