//! Value - Core data types for ZON representation.

const std = @import("std");
const Allocator = std.mem.Allocator;

/// ZON value types.
pub const Value = union(enum) {
    null_val,
    bool_val: bool,
    number: Number,
    string: []const u8,
    identifier: []const u8,
    object: Object,
    array: Array,

    /// Numeric value.
    pub const Number = union(enum) {
        int: i128,
        float: f64,
    };

    /// Object type - key-value map.
    pub const Object = struct {
        allocator: Allocator,
        entries: std.StringHashMapUnmanaged(Value),

        pub fn init(allocator: Allocator) Object {
            return .{
                .allocator = allocator,
                .entries = .{},
            };
        }

        pub fn deinit(self: *Object) void {
            var it = self.entries.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            self.entries.deinit(self.allocator);
        }

        pub fn get(self: *const Object, key: []const u8) ?*Value {
            return self.entries.getPtr(key);
        }

        /// Alias for get().
        pub fn fetch(self: *const Object, key: []const u8) ?*Value {
            return self.get(key);
        }

        /// Alias for get().
        pub fn at(self: *const Object, key: []const u8) ?*Value {
            return self.get(key);
        }

        pub fn put(self: *Object, key: []const u8, value: Value) !void {
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);

            if (self.entries.getPtr(key)) |existing| {
                existing.deinit(self.allocator);
                existing.* = value;
                self.allocator.free(owned_key);
            } else {
                try self.entries.put(self.allocator, owned_key, value);
            }
        }

        /// Alias for put().
        pub fn set(self: *Object, key: []const u8, value: Value) !void {
            try self.put(key, value);
        }

        /// Alias for put().
        pub fn insert(self: *Object, key: []const u8, value: Value) !void {
            try self.put(key, value);
        }

        pub fn remove(self: *Object, key: []const u8) bool {
            if (self.entries.fetchRemove(key)) |kv| {
                self.allocator.free(kv.key);
                var v = kv.value;
                v.deinit(self.allocator);
                return true;
            }
            return false;
        }

        /// Alias for remove().
        pub fn delete(self: *Object, key: []const u8) bool {
            return self.remove(key);
        }

        /// Alias for remove().
        pub fn unset(self: *Object, key: []const u8) bool {
            return self.remove(key);
        }

        pub fn count(self: *const Object) usize {
            return self.entries.count();
        }

        /// Alias for count().
        pub fn size(self: *const Object) usize {
            return self.count();
        }

        /// Alias for count().
        pub fn len(self: *const Object) usize {
            return self.count();
        }

        pub fn keys(self: *const Object, allocator: Allocator) ![][]const u8 {
            const key_count = self.entries.count();
            const result = try allocator.alloc([]const u8, key_count);
            var i: usize = 0;
            var it = self.entries.keyIterator();
            while (it.next()) |key| {
                result[i] = key.*;
                i += 1;
            }
            return result;
        }

        /// Iterator for object entries.
        pub const Iterator = struct {
            it: std.StringHashMapUnmanaged(Value).Iterator,

            pub fn next(self: *Iterator) ?struct { key: []const u8, value: *Value } {
                if (self.it.next()) |entry| {
                    return .{ .key = entry.key_ptr.*, .value = entry.value_ptr };
                }
                return null;
            }
        };

        /// Returns an iterator over the object's entries.
        pub fn iterator(self: *Object) Iterator {
            return .{ .it = self.entries.iterator() };
        }

        /// Removes all entries from the object.
        pub fn clear(self: *Object) void {
            var it = self.entries.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                entry.value_ptr.deinit(self.allocator);
            }
            self.entries.clearRetainingCapacity();
        }

        /// Alias for clear().
        pub fn reset(self: *Object) void {
            self.clear();
        }

        /// Alias for clear().
        pub fn empty(self: *Object) void {
            self.clear();
        }
    };

    /// Array type - ordered list of values.
    pub const Array = struct {
        allocator: Allocator,
        items: std.ArrayListUnmanaged(Value),

        pub fn init(allocator: Allocator) Array {
            return .{
                .allocator = allocator,
                .items = .{},
            };
        }

        pub fn deinit(self: *Array) void {
            for (self.items.items) |*item| {
                item.deinit(self.allocator);
            }
            self.items.deinit(self.allocator);
        }

        pub fn append(self: *Array, value: Value) !void {
            try self.items.append(self.allocator, value);
        }

        /// Alias for append().
        pub fn add(self: *Array, value: Value) !void {
            try self.append(value);
        }

        /// Alias for append().
        pub fn push(self: *Array, value: Value) !void {
            try self.append(value);
        }

        pub fn get(self: *const Array, index: usize) ?*Value {
            if (index >= self.items.items.len) return null;
            return &self.items.items[index];
        }

        /// Alias for get().
        pub fn at(self: *const Array, index: usize) ?*Value {
            return self.get(index);
        }

        pub fn insert(self: *Array, index: usize, value: Value) !void {
            try self.items.insert(self.allocator, index, value);
        }

        pub fn len(self: *const Array) usize {
            return self.items.items.len;
        }

        /// Alias for len().
        pub fn size(self: *const Array) usize {
            return self.len();
        }

        /// Alias for len().
        pub fn count(self: *const Array) usize {
            return self.len();
        }

        pub fn remove(self: *Array, index: usize) bool {
            if (index >= self.items.items.len) return false;
            var item = self.items.orderedRemove(index);
            item.deinit(self.allocator);
            return true;
        }

        /// Iterator for array elements.
        pub const Iterator = struct {
            array: *const Array,
            index: usize = 0,

            pub fn next(self: *Iterator) ?*Value {
                if (self.index >= self.array.len()) return null;
                const val = &self.array.items.items[self.index];
                self.index += 1;
                return val;
            }
        };

        /// Returns an iterator over the array's elements.
        pub fn iterator(self: *const Array) Iterator {
            return .{ .array = self };
        }

        /// Removes all elements from the array.
        pub fn clear(self: *Array) void {
            for (self.items.items) |*item| {
                item.deinit(self.allocator);
            }
            self.items.clearRetainingCapacity();
        }

        /// Alias for clear().
        pub fn reset(self: *Array) void {
            self.clear();
        }

        /// Alias for clear().
        pub fn empty(self: *Array) void {
            self.clear();
        }
    };

    /// Frees all memory.
    pub fn deinit(self: *Value, allocator: Allocator) void {
        switch (self.*) {
            .string => |s| allocator.free(s),
            .identifier => |s| allocator.free(s),
            .object => |*o| o.deinit(),
            .array => |*a| a.deinit(),
            else => {},
        }
    }

    /// Creates a deep copy.
    pub fn clone(self: *const Value, allocator: Allocator) !Value {
        return switch (self.*) {
            .null_val => .null_val,
            .bool_val => |b| .{ .bool_val = b },
            .number => |n| .{ .number = n },
            .string => |s| .{ .string = try allocator.dupe(u8, s) },
            .identifier => |s| .{ .identifier = try allocator.dupe(u8, s) },
            .object => |o| blk: {
                var new_obj = Object.init(allocator);
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const cloned_val = try entry.value_ptr.clone(allocator);
                    try new_obj.put(entry.key_ptr.*, cloned_val);
                }
                break :blk .{ .object = new_obj };
            },
            .array => |a| blk: {
                var new_arr = Array.init(allocator);
                for (a.items.items) |*item| {
                    const cloned_item = try item.clone(allocator);
                    try new_arr.append(cloned_item);
                }
                break :blk .{ .array = new_arr };
            },
        };
    }

    pub fn asString(self: *const Value) ?[]const u8 {
        return switch (self.*) {
            .string => |s| s,
            .identifier => |s| s,
            else => null,
        };
    }

    pub fn asIdentifier(self: *const Value) ?[]const u8 {
        return switch (self.*) {
            .identifier => |s| s,
            else => null,
        };
    }

    pub fn isIdentifier(self: *const Value) bool {
        return self.* == .identifier;
    }

    pub fn asBool(self: *const Value) ?bool {
        return switch (self.*) {
            .bool_val => |b| b,
            else => null,
        };
    }

    pub fn asInt(self: *const Value) ?i64 {
        return switch (self.*) {
            .number => |n| switch (n) {
                .int => |i| if (i >= std.math.minInt(i64) and i <= std.math.maxInt(i64)) @intCast(i) else null,
                .float => |f| if (@abs(f - @trunc(f)) < 0.0001) @as(i64, @intFromFloat(f)) else null,
            },
            else => null,
        };
    }

    /// Returns the integer value as i128.
    pub fn asInt128(self: *const Value) ?i128 {
        return switch (self.*) {
            .number => |n| switch (n) {
                .int => |i| i,
                .float => |f| if (@abs(f - @trunc(f)) < 0.0001) @intFromFloat(f) else null,
            },
            else => null,
        };
    }

    pub fn asFloat(self: *const Value) ?f64 {
        return switch (self.*) {
            .number => |n| switch (n) {
                .float => |f| f,
                .int => |i| @floatFromInt(i),
            },
            else => null,
        };
    }

    pub fn isNull(self: *const Value) bool {
        return self.* == .null_val;
    }

    pub fn asObject(self: *Value) ?*Object {
        return switch (self.*) {
            .object => |*o| o,
            else => null,
        };
    }

    pub fn asArray(self: *Value) ?*Array {
        return switch (self.*) {
            .array => |*a| a,
            else => null,
        };
    }

    /// Returns an unsigned integer value if representable.
    /// Useful for fingerprints and other unsigned values.
    pub fn asUint(self: *const Value) ?u64 {
        return switch (self.*) {
            .number => |n| switch (n) {
                .int => |i| if (i >= 0 and i <= std.math.maxInt(u64)) @intCast(i) else null,
                .float => |f| if (f >= 0 and @abs(f - @trunc(f)) < 0.0001 and f <= @as(f64, @floatFromInt(std.math.maxInt(u64)))) @intFromFloat(f) else null,
            },
            else => null,
        };
    }

    /// Check if this value is positive infinity (like std.zon supports).
    pub fn isPositiveInf(self: *const Value) bool {
        return switch (self.*) {
            .number => |n| switch (n) {
                .float => |f| std.math.isPositiveInf(f),
                else => false,
            },
            else => false,
        };
    }

    /// Check if this value is negative infinity.
    pub fn isNegativeInf(self: *const Value) bool {
        return switch (self.*) {
            .number => |n| switch (n) {
                .float => |f| std.math.isNegativeInf(f),
                else => false,
            },
            else => false,
        };
    }

    /// Check if this value is NaN.
    pub fn isNan(self: *const Value) bool {
        return switch (self.*) {
            .number => |n| switch (n) {
                .float => |f| std.math.isNan(f),
                else => false,
            },
            else => false,
        };
    }

    /// Check if this value is a special float (inf, -inf, nan).
    pub fn isSpecialFloat(self: *const Value) bool {
        return self.isPositiveInf() or self.isNegativeInf() or self.isNan();
    }

    /// Returns a stable 64-bit hash of the value.
    /// Objects are hashed by sorted keys to ensure order independence.
    pub fn hash(self: *const Value) u64 {
        var hasher = std.hash.Wyhash.init(0);
        self.updateHash(&hasher);
        return hasher.final();
    }

    /// Updates the hasher with the content of this value.
    fn updateHash(self: *const Value, hasher: *std.hash.Wyhash) void {
        hasher.update(std.mem.asBytes(&@as(u8, @intFromEnum(std.meta.activeTag(self.*)))));
        switch (self.*) {
            .null_val => {},
            .bool_val => |b| hasher.update(std.mem.asBytes(&b)),
            .number => |n| switch (n) {
                .int => |i| hasher.update(std.mem.asBytes(&i)),
                .float => |f| hasher.update(std.mem.asBytes(&f)),
            },
            .string => |s| hasher.update(s),
            .identifier => |s| hasher.update(s),
            .object => |o| {
                // To ensure order-independent hashing, we hash entries and XOR them,
                // or sort keys. Since we want a single stable hash, we sort.
                // Note: For extreme performance, we could XOR the hashes of (key + val).
                // But for ZON configs, sorting is fast enough and more robust.
                var keys_buf: std.ArrayListUnmanaged([]const u8) = .empty;
                defer keys_buf.deinit(o.allocator);

                var it = o.entries.keyIterator();
                while (it.next()) |k| keys_buf.append(o.allocator, k.*) catch break;
                std.mem.sort([]const u8, keys_buf.items, {}, struct {
                    fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                        return std.mem.order(u8, a, b) == .lt;
                    }
                }.lessThan);

                for (keys_buf.items) |key| {
                    hasher.update(key);
                    const val = o.entries.getPtr(key).?;
                    val.updateHash(hasher);
                }
            },
            .array => |a| {
                for (a.items.items) |*item| {
                    item.updateHash(hasher);
                }
            },
        }
    }

    /// Generates a checksum using the provided algorithm (e.g., std.crypto.hash.sha2.Sha256).
    /// Returns the digest.
    pub fn checksum(self: *const Value, comptime Algo: type, out: *[Algo.digest_length]u8) void {
        var h = Algo.init(.{});
        // We use stringify to get a stable byte representation for the checksum.
        // This is easier than manually feeding the hasher and matches the file content.
        // However, a document-based hash is more robust against formatting.
        // Let's use the internal hash result as a seed or use a dummy buffer.

        // Strategy: We want the checksum of the DATA, not the FORMAT.
        // So we feed the stable hash or a canonical stringification.
        const hash_val = self.hash();
        h.update(std.mem.asBytes(&hash_val));
        h.final(out);
    }

    /// Returns true if this value deeply equals another value.
    pub fn eql(self: *const Value, other: *const Value) bool {
        return switch (self.*) {
            .null_val => other.* == .null_val,
            .bool_val => |a| switch (other.*) {
                .bool_val => |b| a == b,
                else => false,
            },
            .number => |a| switch (other.*) {
                .number => |b| blk: {
                    const af = switch (a) {
                        .int => |i| @as(f64, @floatFromInt(i)),
                        .float => |f| f,
                    };
                    const bf = switch (b) {
                        .int => |i| @as(f64, @floatFromInt(i)),
                        .float => |f| f,
                    };
                    // Handle NaN
                    if (std.math.isNan(af) and std.math.isNan(bf)) break :blk true;
                    break :blk af == bf;
                },
                else => false,
            },
            .string => |a| switch (other.*) {
                .string => |b| std.mem.eql(u8, a, b),
                else => false,
            },
            .identifier => |a| switch (other.*) {
                .identifier => |b| std.mem.eql(u8, a, b),
                else => false,
            },
            .object => |a| switch (other.*) {
                .object => |b| blk: {
                    if (a.count() != b.count()) break :blk false;
                    var it = a.entries.iterator();
                    while (it.next()) |entry| {
                        const other_val = b.entries.getPtr(entry.key_ptr.*) orelse break :blk false;
                        if (!entry.value_ptr.eql(other_val)) break :blk false;
                    }
                    break :blk true;
                },
                else => false,
            },
            .array => |a| switch (other.*) {
                .array => |b| blk: {
                    if (a.len() != b.len()) break :blk false;
                    for (a.items.items, 0..) |*item, i| {
                        if (!item.eql(&b.items.items[i])) break :blk false;
                    }
                    break :blk true;
                },
                else => false,
            },
        };
    }

    /// Returns the type name as a string.
    pub fn typeName(self: *const Value) []const u8 {
        return switch (self.*) {
            .null_val => "null",
            .bool_val => "bool",
            .number => |n| switch (n) {
                .int => "int",
                .float => "float",
            },
            .string => "string",
            .identifier => "identifier",
            .object => "object",
            .array => "array",
        };
    }

    /// Attempts to coerce the value to a boolean.
    /// - null -> false
    /// - bool -> bool
    /// - int 0 -> false, else true
    /// - empty string/array/object -> false, else true
    pub fn toBool(self: *const Value) bool {
        return switch (self.*) {
            .null_val => false,
            .bool_val => |b| b,
            .number => |n| switch (n) {
                .int => |i| i != 0,
                .float => |f| f != 0.0 and !std.math.isNan(f),
            },
            .string => |s| s.len > 0,
            .identifier => |s| s.len > 0,
            .object => |o| o.count() > 0,
            .array => |a| a.len() > 0,
        };
    }

    /// Attempts to convert the value to an integer of type T.
    /// Returns 0 if conversion fails or type is incompatible.
    pub fn toInt(self: *const Value, comptime T: type) T {
        if (self.asInt128()) |i| {
            if (i >= std.math.minInt(T) and i <= std.math.maxInt(T)) {
                return @intCast(i);
            }
        }
        return 0;
    }

    /// Attempts to convert the value to an unsigned integer of type T.
    /// Returns 0 if conversion fails or type is incompatible.
    pub fn toUint(self: *const Value, comptime T: type) T {
        if (self.asUint()) |u| {
            if (u <= std.math.maxInt(T)) {
                return @intCast(u);
            }
        }
        return 0;
    }

    /// Attempts to convert the value to a float of type T.
    /// Returns 0.0 if conversion fails.
    pub fn toFloat(self: *const Value, comptime T: type) T {
        if (self.asFloat()) |f| {
            return @floatCast(f);
        }
        return 0.0;
    }

    /// Converts value to a string representation for debugging.
    pub fn toDebugString(self: *const Value, allocator: Allocator) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();

        try self.formatDebug(buf.writer());
        return buf.toOwnedSlice();
    }

    fn formatDebug(self: *const Value, writer: anytype) !void {
        switch (self.*) {
            .null_val => try writer.writeAll("null"),
            .bool_val => |b| try writer.print("{}", .{b}),
            .number => |n| switch (n) {
                .int => |i| try writer.print("{d}", .{i}),
                .float => |f| {
                    if (std.math.isPositiveInf(f)) {
                        try writer.writeAll("inf");
                    } else if (std.math.isNegativeInf(f)) {
                        try writer.writeAll("-inf");
                    } else if (std.math.isNan(f)) {
                        try writer.writeAll("nan");
                    } else {
                        try writer.print("{d}", .{f});
                    }
                },
            },
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .identifier => |s| try writer.print(".{s}", .{s}),
            .object => try writer.writeAll(".{...}"),
            .array => try writer.writeAll(".{...}"),
        }
    }
};

test "Value: null" {
    var val: Value = .null_val;
    try std.testing.expect(val.isNull());
    try std.testing.expect(val.asString() == null);
}

test "Value: bool" {
    const val_true: Value = .{ .bool_val = true };
    const val_false: Value = .{ .bool_val = false };

    try std.testing.expectEqual(true, val_true.asBool().?);
    try std.testing.expectEqual(false, val_false.asBool().?);
}

test "Value: int" {
    const val: Value = .{ .number = .{ .int = 42 } };
    try std.testing.expectEqual(@as(i64, 42), val.asInt().?);
    try std.testing.expectApproxEqAbs(@as(f64, 42.0), val.asFloat().?, 0.001);
}

test "Value: float" {
    const val: Value = .{ .number = .{ .float = 3.14 } };
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), val.asFloat().?, 0.001);
}

test "Value: string" {
    const allocator = std.testing.allocator;
    const text = try allocator.dupe(u8, "hello");
    var val: Value = .{ .string = text };
    defer val.deinit(allocator);

    try std.testing.expectEqualStrings("hello", val.asString().?);
    try std.testing.expect(!val.isIdentifier());
}

test "Value: identifier" {
    const allocator = std.testing.allocator;
    const text = try allocator.dupe(u8, "my_package");
    var val: Value = .{ .identifier = text };
    defer val.deinit(allocator);

    try std.testing.expectEqualStrings("my_package", val.asIdentifier().?);
    try std.testing.expectEqualStrings("my_package", val.asString().?);
    try std.testing.expect(val.isIdentifier());
}

test "Value: clone" {
    const allocator = std.testing.allocator;
    const text = try allocator.dupe(u8, "original");
    var val: Value = .{ .string = text };
    defer val.deinit(allocator);

    var cloned = try val.clone(allocator);
    defer cloned.deinit(allocator);

    try std.testing.expectEqualStrings("original", cloned.asString().?);
}

test "Value.Object: put and get" {
    const allocator = std.testing.allocator;
    var obj = Value.Object.init(allocator);
    defer obj.deinit();

    try obj.put("name", .{ .bool_val = true });
    const val = obj.get("name").?;
    try std.testing.expectEqual(true, val.asBool().?);
}

test "Value.Object: remove" {
    const allocator = std.testing.allocator;
    var obj = Value.Object.init(allocator);
    defer obj.deinit();

    try obj.put("name", .{ .bool_val = true });
    try std.testing.expect(obj.remove("name"));
    try std.testing.expect(obj.get("name") == null);
}

test "Value.Object: count and keys" {
    const allocator = std.testing.allocator;
    var obj = Value.Object.init(allocator);
    defer obj.deinit();

    try obj.put("a", .{ .bool_val = true });
    try obj.put("b", .{ .bool_val = false });

    try std.testing.expectEqual(@as(usize, 2), obj.count());

    const k = try obj.keys(allocator);
    defer allocator.free(k);
    try std.testing.expectEqual(@as(usize, 2), k.len);
}

test "Value.Array: append and get" {
    const allocator = std.testing.allocator;
    var arr = Value.Array.init(allocator);
    defer arr.deinit();

    try arr.append(.{ .bool_val = true });
    try arr.append(.{ .bool_val = false });

    try std.testing.expectEqual(@as(usize, 2), arr.len());
    try std.testing.expectEqual(true, arr.get(0).?.asBool().?);
    try std.testing.expectEqual(false, arr.get(1).?.asBool().?);
    try std.testing.expect(arr.get(99) == null);
}
