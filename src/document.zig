//! Document - ZON document operations.
//!
//! Provides methods for reading, writing, searching, and saving ZON data.
//! Uses path-based access with dot notation for navigating nested structures.

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const parser = @import("parser.zig");
const stringify = @import("stringify.zig");

/// A parsed ZON document.
pub const Document = struct {
    allocator: Allocator,
    root: Value,
    file_path: ?[]const u8,

    /// Creates an empty document.
    pub fn initEmpty(allocator: Allocator) Document {
        return .{
            .allocator = allocator,
            .root = .{ .object = Value.Object.init(allocator) },
            .file_path = null,
        };
    }

    /// Parses ZON content from source string.
    pub fn initFromSource(allocator: Allocator, source: []const u8) !Document {
        const root = try parser.parse(allocator, source);
        return .{
            .allocator = allocator,
            .root = root,
            .file_path = null,
        };
    }

    /// Opens and parses a ZON file.
    pub fn initFromFile(allocator: Allocator, path: []const u8) !Document {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, 1024 * 1024 * 16);
        defer allocator.free(source);

        var doc = try initFromSource(allocator, source);
        doc.file_path = try allocator.dupe(u8, path);
        return doc;
    }

    /// Frees all resources.
    pub fn deinit(self: *Document) void {
        self.root.deinit(self.allocator);
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Returns the string value at the given path.
    pub fn getString(self: *const Document, path: []const u8) ?[]const u8 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asString();
    }

    /// Returns the boolean value at the given path.
    pub fn getBool(self: *const Document, path: []const u8) ?bool {
        const val = self.getValueByPath(path) orelse return null;
        return val.asBool();
    }

    /// Returns the integer value at the given path.
    pub fn getInt(self: *const Document, path: []const u8) ?i64 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asInt();
    }

    /// Returns the float value at the given path.
    pub fn getFloat(self: *const Document, path: []const u8) ?f64 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asFloat();
    }

    /// Returns the numeric value as float.
    pub fn getNumber(self: *const Document, path: []const u8) ?f64 {
        return self.getFloat(path);
    }

    /// Returns the identifier value at the given path.
    pub fn getIdentifier(self: *const Document, path: []const u8) ?[]const u8 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asIdentifier();
    }

    /// Returns true if the value at the path is an identifier.
    pub fn isIdentifier(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.isIdentifier();
    }

    /// Returns true if the value at the path is null.
    pub fn isNull(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.isNull();
    }

    /// Returns true if the path exists.
    pub fn exists(self: *const Document, path: []const u8) bool {
        return self.getValueByPath(path) != null;
    }

    /// Returns the type of value at the path.
    pub fn getType(self: *const Document, path: []const u8) ?[]const u8 {
        const val = self.getValueByPath(path) orelse return null;
        return switch (val.*) {
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

    /// Returns the raw Value at the given path.
    pub fn getValue(self: *const Document, path: []const u8) ?*const Value {
        return self.getValueByPath(path);
    }

    /// Sets a string value at the given path.
    pub fn setString(self: *Document, path: []const u8, value: []const u8) !void {
        const owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned);
        try self.setValueByPath(path, .{ .string = owned });
    }

    /// Sets an identifier value at the given path. Outputs as `.name = .value`.
    pub fn setIdentifier(self: *Document, path: []const u8, value: []const u8) !void {
        const owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned);
        try self.setValueByPath(path, .{ .identifier = owned });
    }

    /// Sets a boolean value at the given path.
    pub fn setBool(self: *Document, path: []const u8, value: bool) !void {
        try self.setValueByPath(path, .{ .bool_val = value });
    }

    /// Sets an integer value at the given path.
    pub fn setInt(self: *Document, path: []const u8, value: i64) !void {
        try self.setValueByPath(path, .{ .number = .{ .int = value } });
    }

    /// Sets a float value at the given path.
    pub fn setFloat(self: *Document, path: []const u8, value: f64) !void {
        try self.setValueByPath(path, .{ .number = .{ .float = value } });
    }

    /// Sets a numeric value as float.
    pub fn setNumber(self: *Document, path: []const u8, value: f64) !void {
        try self.setFloat(path, value);
    }

    /// Sets the value at the path to null.
    pub fn setNull(self: *Document, path: []const u8) !void {
        try self.setValueByPath(path, .null_val);
    }

    /// Sets an empty object at the given path.
    pub fn setObject(self: *Document, path: []const u8) !void {
        try self.setValueByPath(path, .{ .object = Value.Object.init(self.allocator) });
    }

    /// Sets an empty array at the given path.
    pub fn setArray(self: *Document, path: []const u8) !void {
        try self.setValueByPath(path, .{ .array = Value.Array.init(self.allocator) });
    }

    /// Sets a raw Value at the given path.
    pub fn setValue(self: *Document, path: []const u8, value: Value) !void {
        try self.setValueByPath(path, value);
    }

    /// Deletes the key at the given path. Returns true if it existed.
    pub fn delete(self: *Document, path: []const u8) bool {
        const parts = self.splitPath(path) catch return false;
        defer self.allocator.free(parts);

        if (parts.len == 0) return false;

        if (parts.len == 1) {
            const obj = self.root.asObject() orelse return false;
            return obj.remove(parts[0]);
        }

        var current = self.root.asObject() orelse return false;
        for (parts[0 .. parts.len - 1]) |part| {
            const val = current.get(part) orelse return false;
            current = val.asObject() orelse return false;
        }

        return current.remove(parts[parts.len - 1]);
    }

    /// Clears all data.
    pub fn clear(self: *Document) void {
        self.root.deinit(self.allocator);
        self.root = .{ .object = Value.Object.init(self.allocator) };
    }

    /// Returns the number of keys at the root level.
    pub fn count(self: *const Document) usize {
        return switch (self.root) {
            .object => |o| o.count(),
            else => 0,
        };
    }

    /// Returns all keys at the root level. Caller must free.
    pub fn keys(self: *const Document) ![][]const u8 {
        return switch (self.root) {
            .object => |o| o.keys(self.allocator),
            else => &[_][]const u8{},
        };
    }

    /// Returns true if the document is empty.
    pub fn isEmpty(self: *const Document) bool {
        return self.count() == 0;
    }

    /// Finds all paths containing the given string.
    pub fn findString(self: *const Document, needle: []const u8) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        try self.findStringRecursive(&self.root, "", needle, &results);
        return results.toOwnedSlice(self.allocator);
    }

    /// Finds all paths with an exact string match.
    pub fn findExact(self: *const Document, needle: []const u8) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        try self.findExactRecursive(&self.root, "", needle, &results);
        return results.toOwnedSlice(self.allocator);
    }

    /// Finds all paths where the value matches a predicate.
    pub fn findWhere(self: *const Document, predicate: *const fn (*const Value) bool) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        try self.findWhereRecursive(&self.root, "", predicate, &results);
        return results.toOwnedSlice(self.allocator);
    }

    /// Replaces all occurrences of a string value. Returns count.
    pub fn replaceAll(self: *Document, find: []const u8, replacement: []const u8) !usize {
        return self.replaceInValue(&self.root, find, replacement, .all);
    }

    /// Replaces the first occurrence of a string value.
    pub fn replaceFirst(self: *Document, find: []const u8, replacement: []const u8) !bool {
        const count_val = try self.replaceInValue(&self.root, find, replacement, .first);
        return count_val > 0;
    }

    /// Replaces the last occurrence of a string value.
    pub fn replaceLast(self: *Document, find: []const u8, replacement: []const u8) !bool {
        const paths = try self.findExact(find);
        defer {
            for (paths) |p| self.allocator.free(p);
            self.allocator.free(paths);
        }

        if (paths.len == 0) return false;
        try self.setString(paths[paths.len - 1], replacement);
        return true;
    }

    /// Returns the length of the array at the path.
    pub fn arrayLen(self: *const Document, path: []const u8) ?usize {
        const val = self.getValueByPath(path) orelse return null;
        return switch (val.*) {
            .array => |a| a.len(),
            else => null,
        };
    }

    /// Returns the element at the given array index.
    pub fn getArrayElement(self: *const Document, path: []const u8, index: usize) ?*const Value {
        const val = self.getValueByPath(path) orelse return null;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return null,
        };
        return arr.get(index);
    }

    /// Returns the string at the given array index.
    pub fn getArrayString(self: *const Document, path: []const u8, index: usize) ?[]const u8 {
        const elem = self.getArrayElement(path, index) orelse return null;
        return elem.asString();
    }

    /// Returns the integer at the given array index.
    pub fn getArrayInt(self: *const Document, path: []const u8, index: usize) ?i64 {
        const elem = self.getArrayElement(path, index) orelse return null;
        return elem.asInt();
    }

    /// Returns the boolean at the given array index.
    pub fn getArrayBool(self: *const Document, path: []const u8, index: usize) ?bool {
        const elem = self.getArrayElement(path, index) orelse return null;
        return elem.asBool();
    }

    /// Appends a string to an array.
    pub fn appendToArray(self: *Document, path: []const u8, value: []const u8) !void {
        const owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned);

        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                try arr.append(.{ .string = owned });
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Appends an integer to an array.
    pub fn appendIntToArray(self: *Document, path: []const u8, value: i64) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                try arr.append(.{ .number = .{ .int = value } });
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Appends a float to an array.
    pub fn appendFloatToArray(self: *Document, path: []const u8, value: f64) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                try arr.append(.{ .number = .{ .float = value } });
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Appends a boolean to an array.
    pub fn appendBoolToArray(self: *Document, path: []const u8, value: bool) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                try arr.append(.{ .bool_val = value });
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Saves the document to the original file path.
    pub fn save(self: *const Document) !void {
        const path = self.file_path orelse return error.NoFilePath;
        try self.saveAs(path);
    }

    /// Saves the document to the specified file path.
    pub fn saveAs(self: *const Document, path: []const u8) !void {
        const output = try stringify.stringify(self.allocator, &self.root, .{});
        defer self.allocator.free(output);

        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        try file.writeAll(output);
        try file.writeAll("\n");
    }

    /// Atomically write the document to `path` by writing to a temporary file, then renaming.
    pub fn saveAsAtomic(self: *const Document, path: []const u8) !void {
        const output = try stringify.stringify(self.allocator, &self.root, .{});
        defer self.allocator.free(output);

        const tmp_path = try std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path});
        defer self.allocator.free(tmp_path);

        const tmp_file = try std.fs.cwd().createFile(tmp_path, .{});
        defer tmp_file.close();

        try tmp_file.writeAll(output);
        try tmp_file.writeAll("\n");

        try std.fs.cwd().rename(tmp_path, path);
    }

    /// Save the document to the original file path, creating a backup of the previous file
    /// using the supplied extension (for example, ".bak") if it exists.
    pub fn saveWithBackup(self: *const Document, backup_ext: []const u8) !void {
        const path = self.file_path orelse return error.NoFilePath;

        const file_opt = std.fs.cwd().openFile(path, .{}) catch null;
        if (file_opt != null) {
            var file = file_opt.?;
            defer file.close();

            const backup = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ path, backup_ext });
            defer self.allocator.free(backup);
            try std.fs.cwd().rename(path, backup);
        }

        try self.saveAs(path);
    }

    /// Save only if document content differs from existing file. Returns `true` if a write occurred.
    pub fn saveIfChanged(self: *const Document) !bool {
        const path = self.file_path orelse return error.NoFilePath;

        const new_output = try stringify.stringify(self.allocator, &self.root, .{});
        defer self.allocator.free(new_output);

        const file_opt = std.fs.cwd().openFile(path, .{}) catch null;
        if (file_opt == null) {
            try self.saveAs(path);
            return true;
        }
        var file = file_opt.?;
        defer file.close();

        const existing = try file.readToEndAlloc(self.allocator, 1024 * 1024 * 16);
        defer self.allocator.free(existing);

        // Normalize trailing newline when comparing (we write a trailing newline on save)
        const existing_trim = if (existing.len > 0 and existing[existing.len - 1] == '\n') existing[0 .. existing.len - 1] else existing;
        if (existing_trim.len == new_output.len and std.mem.eql(u8, existing_trim, new_output)) {
            return false;
        }

        try self.saveAsAtomic(path);
        return true;
    }

    /// Returns the ZON string with default formatting.
    pub fn toString(self: *const Document) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{});
    }

    /// Returns the ZON string with no indentation.
    pub fn toCompactString(self: *const Document) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{ .indent = 0 });
    }

    /// Returns the ZON string with custom indentation.
    pub fn toPrettyString(self: *const Document, indent_size: usize) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{ .indent = indent_size });
    }

    /// Merges another document into this one.
    pub fn merge(self: *Document, other: *const Document) !void {
        const other_obj = switch (other.root) {
            .object => |o| o,
            else => return,
        };

        const other_keys = try other_obj.keys(self.allocator);
        defer self.allocator.free(other_keys);

        for (other_keys) |key| {
            if (other_obj.entries.get(key)) |other_val| {
                const cloned = try other_val.clone(self.allocator);
                try self.setValueByPath(key, cloned);
            }
        }
    }

    /// Creates a deep copy of the document.
    pub fn clone(self: *const Document) !Document {
        return .{
            .allocator = self.allocator,
            .root = try self.root.clone(self.allocator),
            .file_path = if (self.file_path) |p| try self.allocator.dupe(u8, p) else null,
        };
    }

    /// Returns keys that differ between this and another document.
    pub fn diff(self: *const Document, other: *const Document) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        const self_keys = try self.keys();
        defer self.allocator.free(self_keys);

        const other_obj = switch (other.root) {
            .object => |o| o,
            else => return results.toOwnedSlice(self.allocator),
        };

        for (self_keys) |key| {
            const self_val = self.getString(key);
            const other_val_ptr = other_obj.entries.get(key);

            if (other_val_ptr == null) {
                const path = try self.allocator.dupe(u8, key);
                try results.append(self.allocator, path);
            } else if (self_val != null) {
                if (other_val_ptr.?.asString()) |other_str| {
                    if (!std.mem.eql(u8, self_val.?, other_str)) {
                        const path = try self.allocator.dupe(u8, key);
                        try results.append(self.allocator, path);
                    }
                }
            }
        }

        return results.toOwnedSlice(self.allocator);
    }

    /// Returns a mutable pointer to the object at the path.
    pub fn getObject(self: *Document, path: []const u8) ?*Value.Object {
        var current: *Value = &self.root;

        if (path.len == 0) {
            return current.asObject();
        }

        var parts_iter = std.mem.splitScalar(u8, path, '.');
        while (parts_iter.next()) |part| {
            switch (current.*) {
                .object => |*obj| {
                    current = obj.get(part) orelse return null;
                },
                else => return null,
            }
        }

        return current.asObject();
    }

    /// Returns a mutable pointer to the array at the path.
    pub fn getArray(self: *Document, path: []const u8) ?*Value.Array {
        var current: *Value = &self.root;

        if (path.len == 0) {
            return current.asArray();
        }

        var parts_iter = std.mem.splitScalar(u8, path, '.');
        while (parts_iter.next()) |part| {
            switch (current.*) {
                .object => |*obj| {
                    current = obj.get(part) orelse return null;
                },
                else => return null,
            }
        }

        return current.asArray();
    }

    const ReplaceMode = enum { all, first };

    fn splitPath(self: *const Document, path: []const u8) ![][]const u8 {
        var parts_iter = std.mem.splitScalar(u8, path, '.');
        var count_val: usize = 0;

        var iter_copy = parts_iter;
        while (iter_copy.next()) |_| {
            count_val += 1;
        }

        const parts = try self.allocator.alloc([]const u8, count_val);
        var i: usize = 0;
        while (parts_iter.next()) |part| {
            parts[i] = part;
            i += 1;
        }

        return parts;
    }

    fn getValueByPath(self: *const Document, path: []const u8) ?*const Value {
        var parts_iter = std.mem.splitScalar(u8, path, '.');
        var current: *const Value = &self.root;

        while (parts_iter.next()) |part| {
            switch (current.*) {
                .object => |*obj| {
                    current = obj.get(part) orelse return null;
                },
                else => return null,
            }
        }

        return current;
    }

    fn getMutableValueByPath(self: *Document, path: []const u8) ?*Value {
        var parts_iter = std.mem.splitScalar(u8, path, '.');
        var current: *Value = &self.root;

        while (parts_iter.next()) |part| {
            switch (current.*) {
                .object => |*obj| {
                    current = obj.get(part) orelse return null;
                },
                else => return null,
            }
        }

        return current;
    }

    fn setValueByPath(self: *Document, path: []const u8, value: Value) !void {
        const parts = try self.splitPath(path);
        defer self.allocator.free(parts);

        if (parts.len == 0) return;

        var current = self.root.asObject() orelse {
            self.root.deinit(self.allocator);
            self.root = .{ .object = Value.Object.init(self.allocator) };
            return self.setValueByPath(path, value);
        };

        for (parts[0 .. parts.len - 1]) |part| {
            if (current.get(part)) |existing| {
                if (existing.asObject()) |obj| {
                    current = obj;
                } else {
                    existing.deinit(self.allocator);
                    existing.* = .{ .object = Value.Object.init(self.allocator) };
                    current = existing.asObject().?;
                }
            } else {
                try current.put(part, .{ .object = Value.Object.init(self.allocator) });
                current = current.get(part).?.asObject().?;
            }
        }

        const last_key = parts[parts.len - 1];
        if (current.get(last_key)) |existing| {
            existing.deinit(self.allocator);
            existing.* = value;
        } else {
            try current.put(last_key, value);
        }
    }

    fn findStringRecursive(self: *const Document, value: *const Value, prefix: []const u8, needle: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (value.*) {
            .string => |s| {
                if (std.mem.indexOf(u8, s, needle) != null) {
                    const path = try self.allocator.dupe(u8, prefix);
                    try results.append(self.allocator, path);
                }
            },
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        try self.allocator.dupe(u8, entry.key_ptr.*)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                    defer self.allocator.free(new_prefix);
                    try self.findStringRecursive(entry.value_ptr, new_prefix, needle, results);
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    defer self.allocator.free(new_prefix);
                    try self.findStringRecursive(item, new_prefix, needle, results);
                }
            },
            else => {},
        }
    }

    fn findExactRecursive(self: *const Document, value: *const Value, prefix: []const u8, needle: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (value.*) {
            .string => |s| {
                if (std.mem.eql(u8, s, needle)) {
                    const path = try self.allocator.dupe(u8, prefix);
                    try results.append(self.allocator, path);
                }
            },
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        try self.allocator.dupe(u8, entry.key_ptr.*)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                    defer self.allocator.free(new_prefix);
                    try self.findExactRecursive(entry.value_ptr, new_prefix, needle, results);
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    defer self.allocator.free(new_prefix);
                    try self.findExactRecursive(item, new_prefix, needle, results);
                }
            },
            else => {},
        }
    }

    fn findWhereRecursive(self: *const Document, value: *const Value, prefix: []const u8, predicate: *const fn (*const Value) bool, results: *std.ArrayListUnmanaged([]const u8)) !void {
        if (predicate(value)) {
            const path = try self.allocator.dupe(u8, prefix);
            try results.append(self.allocator, path);
        }

        switch (value.*) {
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        try self.allocator.dupe(u8, entry.key_ptr.*)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                    defer self.allocator.free(new_prefix);
                    try self.findWhereRecursive(entry.value_ptr, new_prefix, predicate, results);
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    defer self.allocator.free(new_prefix);
                    try self.findWhereRecursive(item, new_prefix, predicate, results);
                }
            },
            else => {},
        }
    }

    fn replaceInValue(self: *Document, value: *Value, find: []const u8, replacement: []const u8, mode: ReplaceMode) !usize {
        var replaced: usize = 0;

        switch (value.*) {
            .string => |s| {
                if (std.mem.eql(u8, s, find)) {
                    self.allocator.free(s);
                    value.* = .{ .string = try self.allocator.dupe(u8, replacement) };
                    replaced += 1;
                }
            },
            .object => |*o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const count_val = try self.replaceInValue(entry.value_ptr, find, replacement, mode);
                    replaced += count_val;
                    if (mode == .first and replaced > 0) return replaced;
                }
            },
            .array => |*a| {
                for (a.items.items) |*item| {
                    const count_val = try self.replaceInValue(item, find, replacement, mode);
                    replaced += count_val;
                    if (mode == .first and replaced > 0) return replaced;
                }
            },
            else => {},
        }

        return replaced;
    }
};

test "Document: create empty" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try std.testing.expect(doc.isEmpty());
    try std.testing.expectEqual(@as(usize, 0), doc.count());
}

test "Document: set and get string" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try std.testing.expectEqualStrings("myapp", doc.getString("name").?);
    try std.testing.expect(doc.getBool("name") == null);
}

test "Document: set and get identifier" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setIdentifier("name", "my_package");
    try std.testing.expectEqualStrings("my_package", doc.getIdentifier("name").?);
    try std.testing.expect(doc.isIdentifier("name"));
    try std.testing.expectEqualStrings("identifier", doc.getType("name").?);
}

test "Document: set and get bool" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setBool("enabled", true);
    try std.testing.expectEqual(true, doc.getBool("enabled").?);
}

test "Document: set and get int" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setInt("port", 8080);
    try std.testing.expectEqual(@as(i64, 8080), doc.getInt("port").?);
}

test "Document: set and get float" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setFloat("score", 3.14);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), doc.getFloat("score").?, 0.001);
}

test "Document: nested paths" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("server.host", "localhost");
    try doc.setInt("server.port", 8080);
    try doc.setBool("server.ssl.enabled", true);

    try std.testing.expectEqualStrings("localhost", doc.getString("server.host").?);
    try std.testing.expectEqual(@as(i64, 8080), doc.getInt("server.port").?);
    try std.testing.expectEqual(true, doc.getBool("server.ssl.enabled").?);
}

test "Document: delete" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try std.testing.expect(doc.exists("name"));
    try std.testing.expect(doc.delete("name"));
    try std.testing.expect(!doc.exists("name"));
    try std.testing.expect(!doc.delete("nonexistent"));
}

test "Document: clear" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "1");
    try doc.setString("b", "2");
    try std.testing.expectEqual(@as(usize, 2), doc.count());

    doc.clear();
    try std.testing.expect(doc.isEmpty());
}

test "Document: array operations" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("paths");
    try doc.appendToArray("paths", "src");
    try doc.appendToArray("paths", "lib");

    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("paths").?);
    try std.testing.expectEqualStrings("src", doc.getArrayString("paths", 0).?);
    try std.testing.expectEqualStrings("lib", doc.getArrayString("paths", 1).?);
}

test "Document: find and replace" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "hello");
    try doc.setString("b", "hello");
    try doc.setString("c", "world");

    const count_val = try doc.replaceAll("hello", "goodbye");
    try std.testing.expectEqual(@as(usize, 2), count_val);
    try std.testing.expectEqualStrings("goodbye", doc.getString("a").?);
    try std.testing.expectEqualStrings("world", doc.getString("c").?);
}

test "Document: clone" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "original");
    var cloned = try doc.clone();
    defer cloned.deinit();

    try doc.setString("name", "modified");
    try std.testing.expectEqualStrings("original", cloned.getString("name").?);
}

test "Document: saveIfChanged writes file and avoids unnecessary writes" {
    const allocator = std.testing.allocator;
    const path = "test_save_if_changed.zon";

    // Ensure no leftover file
    _ = std.fs.cwd().deleteFile(path) catch null;

    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "one");

    // set file_path so saveIfChanged can use it
    doc.file_path = try allocator.dupe(u8, path);

    // First save should write the file
    const changed1 = try doc.saveIfChanged();
    try std.testing.expect(changed1);

    // Second save without changes should not write
    const changed2 = try doc.saveIfChanged();
    try std.testing.expect(!changed2);

    // Modify and save again
    try doc.setString("b", "two");
    const changed3 = try doc.saveIfChanged();
    try std.testing.expect(changed3);

    // Cleanup
    _ = std.fs.cwd().deleteFile(path) catch null;
}

test "Document: type checking" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("str", "hello");
    try doc.setInt("int", 42);
    try doc.setBool("bool", true);
    try doc.setNull("null");

    try std.testing.expectEqualStrings("string", doc.getType("str").?);
    try std.testing.expectEqualStrings("int", doc.getType("int").?);
    try std.testing.expectEqualStrings("bool", doc.getType("bool").?);
    try std.testing.expectEqualStrings("null", doc.getType("null").?);
    try std.testing.expect(doc.isNull("null"));
}

test "Document: exists" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try std.testing.expect(doc.exists("name"));
    try std.testing.expect(!doc.exists("nonexistent"));
}

test "Document: keys" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "1");
    try doc.setString("b", "2");

    const k = try doc.keys();
    defer allocator.free(k);

    try std.testing.expectEqual(@as(usize, 2), k.len);
}

test "Document: toString" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");

    const output = try doc.toString();
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, ".name") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"test\"") != null);
}
