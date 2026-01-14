//! Document - ZON document operations.
//!
//! Provides a DOM-like interface for working with ZON data. The Document maintains
//! an in-memory Value tree that can be queried, modified, and serialized.
//!
//! This approach differs from `std.zon.fromSlice` which deserializes directly into
//! typed Zig structures. Document-based access is ideal when:
//! - You need to edit and save configuration files
//! - The structure isn't known at compile time
//! - You want path-based access (e.g., "server.ssl.enabled")
//! - You need find/replace or merge operations

const std = @import("std");
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const parser = @import("parser.zig");
const stringify = @import("stringify.zig");
const utils = @import("utils.zig");

/// A parsed ZON document.
pub const Document = struct {
    allocator: Allocator,
    root: Value,
    file_path: ?[]const u8,
    last_mtime: i128 = 0,

    /// Creates an empty document.
    pub fn initEmpty(allocator: Allocator) Document {
        return .{
            .allocator = allocator,
            .root = .{ .object = Value.Object.init(allocator) },
            .file_path = null,
            .last_mtime = 0,
        };
    }

    /// Parses ZON content from source string.
    pub fn initFromSource(allocator: Allocator, source: []const u8) !Document {
        const root = try parser.parse(allocator, source);
        return .{
            .allocator = allocator,
            .root = root,
            .file_path = null,
            .last_mtime = 0,
        };
    }

    /// Parses JSON content from source string.
    pub fn initFromJson(allocator: Allocator, source: []const u8) !Document {
        const root = try parser.Parser.parseJson(allocator, source);
        return .{
            .allocator = allocator,
            .root = root,
            .file_path = null,
        };
    }

    /// Creates a document from a map of key-value pairs (dot-notation).
    pub fn initFromMap(allocator: Allocator, map: anytype) !Document {
        var doc = initEmpty(allocator);
        errdefer doc.deinit();

        const info = @typeInfo(@TypeOf(map));
        if (info == .@"struct") {
            inline for (info.@"struct".fields) |field| {
                const val = @field(map, field.name);
                switch (@typeInfo(@TypeOf(val))) {
                    .int, .comptime_int => try doc.setInt(field.name, @intCast(val)),
                    .float, .comptime_float => try doc.setFloat(field.name, @floatCast(val)),
                    .bool => try doc.setBool(field.name, val),
                    .pointer => |p| {
                        if (p.size == .slice) {
                            if (p.child == u8) try doc.setString(field.name, val);
                        } else if (p.size == .one) {
                            const child_info = @typeInfo(p.child);
                            if (child_info == .array and child_info.array.child == u8) {
                                try doc.setString(field.name, val[0..]);
                            }
                        }
                    },
                    else => {},
                }
            }
        }
        return doc;
    }

    /// Creates a document from a Zig struct or value.
    pub fn initFromStruct(allocator: Allocator, value: anytype) !Document {
        const root = try Value.from(allocator, value);
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

        const stat = try file.stat();
        const mtime = stat.mtime;

        const source = try file.readToEndAlloc(allocator, 1024 * 1024 * 16);
        defer allocator.free(source);

        var doc = try initFromSource(allocator, source);
        doc.file_path = try utils.dupeString(allocator, path);
        doc.last_mtime = mtime;
        return doc;
    }

    /// Frees all resources.
    pub fn deinit(self: *Document) void {
        self.root.deinit(self.allocator);
        if (self.file_path) |path| {
            self.allocator.free(path);
        }
    }

    /// Alias for deinit().
    pub fn close(self: *Document) void {
        self.deinit();
    }

    /// Returns the string value at the given path.
    pub fn getString(self: *const Document, path: []const u8) ?[]const u8 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asString();
    }

    /// Alias for getString().
    pub fn getStr(self: *const Document, path: []const u8) ?[]const u8 {
        return self.getString(path);
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

    /// Alias for getInt().
    pub fn getNum(self: *const Document, path: []const u8) ?i64 {
        return self.getInt(path);
    }

    /// Alias for getInt().
    pub fn getInteger(self: *const Document, path: []const u8) ?i64 {
        return self.getInt(path);
    }

    /// Returns the integer value as i128 at the given path.
    pub fn getInt128(self: *const Document, path: []const u8) ?i128 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asInt128();
    }

    /// Returns the unsigned integer value at the given path.
    pub fn getUint(self: *const Document, path: []const u8) ?u64 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asUint();
    }

    /// Coerces the value at the path to a boolean value.
    pub fn toBool(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.toBool();
    }

    /// Returns the float value at the given path.
    pub fn getFloat(self: *const Document, path: []const u8) ?f64 {
        const val = self.getValueByPath(path) orelse return null;
        return val.asFloat();
    }

    /// Alias for getFloat().
    pub fn getDecimal(self: *const Document, path: []const u8) ?f64 {
        return self.getFloat(path);
    }

    /// Returns the numeric value as float.
    pub fn getNumber(self: *const Document, path: []const u8) ?f64 {
        return self.getFloat(path);
    }

    /// Attempts to convert the value at the path to an integer of type T.
    pub fn toInt(self: *const Document, path: []const u8, comptime T: type) T {
        const val = self.getValueByPath(path) orelse return 0;
        return val.toInt(T);
    }

    /// Attempts to convert the value at the path to an unsigned integer of type T.
    pub fn toUint(self: *const Document, path: []const u8, comptime T: type) T {
        const val = self.getValueByPath(path) orelse return 0;
        return val.toUint(T);
    }

    /// Attempts to convert the value at the path to a float of type T.
    pub fn toFloat(self: *const Document, path: []const u8, comptime T: type) T {
        const val = self.getValueByPath(path) orelse return 0.0;
        return val.toFloat(T);
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

    /// Alias for exists().
    pub fn has(self: *const Document, path: []const u8) bool {
        return self.exists(path);
    }

    /// Alias for exists().
    pub fn contains(self: *const Document, path: []const u8) bool {
        return self.exists(path);
    }

    /// Returns the string value at the path, or a default value.
    pub fn getStringOr(self: *const Document, path: []const u8, default: []const u8) []const u8 {
        return self.getString(path) orelse default;
    }

    /// Returns the integer value at the path, or a default value.
    pub fn getIntOr(self: *const Document, path: []const u8, default: i64) i64 {
        return self.getInt(path) orelse default;
    }

    /// Returns the boolean value at the path, or a default value.
    pub fn getBoolOr(self: *const Document, path: []const u8, default: bool) bool {
        return self.getBool(path) orelse default;
    }

    /// Returns the float value at the path, or a default value.
    pub fn getFloatOr(self: *const Document, path: []const u8, default: f64) f64 {
        return self.getFloat(path) orelse default;
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

    /// Converts the document (or object at root) into a Zig type T.
    pub fn toStruct(self: *const Document, comptime T: type) !T {
        return self.root.to(self.allocator, T);
    }

    /// Returns the precise type name of the value at the path.
    pub fn getTypeName(self: *const Document, path: []const u8) ?[]const u8 {
        const val = self.getValueByPath(path) orelse return null;
        return val.typeName();
    }

    /// Returns the raw Value at the given path.
    pub fn getValue(self: *const Document, path: []const u8) ?*const Value {
        return self.getValueByPath(path);
    }

    /// Checks if two documents are deeply equal.
    pub fn eql(self: *const Document, other: *const Document) bool {
        return self.root.eql(&other.root);
    }

    /// Checks if the value at the path is NaN.
    pub fn isNan(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.isNan();
    }

    /// Checks if the value at the path is infinity.
    pub fn isInf(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.isPositiveInf() or val.isNegativeInf();
    }

    /// Sets a string value at the given path.
    pub fn setString(self: *Document, path: []const u8, value: []const u8) !void {
        const owned = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned);
        try self.setValueByPath(path, .{ .string = owned });
    }

    /// Alias for setString().
    pub fn setStr(self: *Document, path: []const u8, value: []const u8) !void {
        try self.setString(path, value);
    }

    /// Alias for setString().
    pub fn putStr(self: *Document, path: []const u8, value: []const u8) !void {
        try self.setString(path, value);
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

    /// Alias for setInt().
    pub fn putInt(self: *Document, path: []const u8, value: i64) !void {
        try self.setInt(path, value);
    }

    /// Alias for setInt().
    pub fn setNum(self: *Document, path: []const u8, value: i64) !void {
        try self.setInt(path, value);
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

    /// Alias for setNull().
    pub fn putNull(self: *Document, path: []const u8) !void {
        try self.setNull(path);
    }

    /// Alias for setNull().
    pub fn clearPath(self: *Document, path: []const u8) !void {
        try self.setNull(path);
    }

    /// Sets an empty object at the given path.
    pub fn setObject(self: *Document, path: []const u8) !void {
        try self.setValueByPath(path, .{ .object = Value.Object.init(self.allocator) });
    }

    /// Sets an empty array at the given path.
    pub fn setArray(self: *Document, path: []const u8) !void {
        try self.setValueByPath(path, .{ .array = Value.Array.init(self.allocator) });
    }

    /// Sets a value at path from a Zig struct/value.
    pub fn setFromStruct(self: *Document, path: []const u8, value: anytype) !void {
        try self.setValueByPath(path, try Value.from(self.allocator, value));
    }

    /// Sets a raw Value at the given path.
    pub fn setValue(self: *Document, path: []const u8, value: Value) !void {
        try self.setValueByPath(path, value);
    }

    /// Alias for setValue().
    pub fn put(self: *Document, path: []const u8, value: Value) !void {
        try self.setValue(path, value);
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

    /// Renames a key from old_path to new_path.
    pub fn rename(self: *Document, old_path: []const u8, new_path: []const u8) !bool {
        const val = self.getValue(old_path) orelse return false;
        const cloned = try val.clone(self.allocator);
        try self.setValue(new_path, cloned);
        _ = self.delete(old_path);
        return true;
    }

    /// Copies a value from src_path to dst_path.
    pub fn copy(self: *Document, src_path: []const u8, dst_path: []const u8) !bool {
        const val = self.getValue(src_path) orelse return false;
        const cloned = try val.clone(self.allocator);
        try self.setValue(dst_path, cloned);
        return true;
    }

    /// Alias for rename().
    pub fn move(self: *Document, old_path: []const u8, new_path: []const u8) !bool {
        return self.rename(old_path, new_path);
    }

    /// Alias for delete().
    pub fn remove(self: *Document, path: []const u8) bool {
        return self.delete(path);
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

    /// Alias for count().
    pub fn size(self: *const Document) usize {
        return self.count();
    }

    /// Alias for count().
    pub fn len(self: *const Document) usize {
        return self.count();
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

        self.findStringRecursive(&self.root, "", needle, &results) catch |err| return err;
        return results.toOwnedSlice(self.allocator);
    }

    /// Finds all paths with an exact string match.
    pub fn findExact(self: *const Document, needle: []const u8) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        self.findExactRecursive(&self.root, "", needle, &results) catch |err| return err;
        return results.toOwnedSlice(self.allocator);
    }

    /// Finds all paths where the value matches a predicate.
    pub fn findWhere(self: *const Document, predicate: *const fn (*const Value) bool) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |item| self.allocator.free(item);
            results.deinit(self.allocator);
        }

        self.findWhereRecursive(&self.root, "", predicate, &results) catch |err| return err;
        return results.toOwnedSlice(self.allocator);
    }

    /// Replaces all occurrences of a string value. Returns count.
    pub fn replaceAll(self: *Document, needle: []const u8, replacement: []const u8) !usize {
        return self.replaceInValue(&self.root, needle, replacement, .all);
    }

    /// Replaces the first occurrence of a string value.
    pub fn replaceFirst(self: *Document, needle: []const u8, replacement: []const u8) !bool {
        const count_val = self.replaceInValue(&self.root, needle, replacement, .first) catch |err| return err;
        return count_val > 0;
    }

    /// Replaces the last occurrence of a string value.
    pub fn replaceLast(self: *Document, needle: []const u8, replacement: []const u8) !bool {
        const paths = self.findExact(needle) catch |err| return err;
        defer {
            for (paths) |p| self.allocator.free(p);
            self.allocator.free(paths);
        }

        if (paths.len == 0) return false;
        self.setString(paths[paths.len - 1], replacement) catch |err| return err;
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
        const owned = self.allocator.dupe(u8, value) catch |err| return err;
        errdefer self.allocator.free(owned);

        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                arr.append(.{ .string = owned }) catch |err| return err;
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Appends an integer to an array.
    pub fn appendIntToArray(self: *Document, path: []const u8, value: i128) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                arr.append(.{ .number = .{ .int = value } }) catch |err| return err;
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
                arr.append(.{ .number = .{ .float = value } }) catch |err| return err;
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
                arr.append(.{ .bool_val = value }) catch |err| return err;
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Removes an element from an array at the given index.
    pub fn removeFromArray(self: *Document, path: []const u8, index: usize) bool {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                return arr.remove(index);
            }
        }
        return false;
    }

    /// Removes the last element from an array and returns its value (if any).
    /// Caller must free returned value if it contains allocated memory.
    /// Note: Returns a copy of the value, original is removed from array.
    pub fn popFromArray(self: *Document, path: []const u8) ?Value {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                return arr.pop();
            }
        }
        return null;
    }

    /// Removes the first element from an array and returns its value (if any).
    /// Caller must free.
    pub fn shiftArray(self: *Document, path: []const u8) ?Value {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                return arr.shift();
            }
        }
        return null;
    }

    /// Inserts a value at the beginning of an array.
    pub fn unshiftArray(self: *Document, path: []const u8, value: Value) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                arr.unshift(value) catch |err| return err;
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Returns the number of keys or elements at the given path.
    pub fn countAt(self: *const Document, path: []const u8) usize {
        const val = self.getValueByPath(path) orelse return 0;
        return switch (val.*) {
            .object => |o| o.count(),
            .array => |a| a.len(),
            else => 0,
        };
    }

    /// Inserts a string into an array at the given index.
    pub fn insertStringIntoArray(self: *Document, path: []const u8, index: usize, value: []const u8) !void {
        const owned = self.allocator.dupe(u8, value) catch |err| return err;
        errdefer self.allocator.free(owned);

        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                arr.insert(index, .{ .string = owned }) catch |err| return err;
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Inserts an integer into an array at the given index.
    pub fn insertIntIntoArray(self: *Document, path: []const u8, index: usize, value: i128) !void {
        const val = self.getMutableValueByPath(path);
        if (val) |v| {
            if (v.asArray()) |arr| {
                arr.insert(index, .{ .number = .{ .int = value } }) catch |err| return err;
                return;
            }
        }
        return error.NotAnArray;
    }

    /// Returns the index of a string in an array, or null if not found.
    pub fn indexOf(self: *const Document, path: []const u8, value: []const u8) ?usize {
        const val = self.getValueByPath(path) orelse return null;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return null,
        };

        for (arr.items.items, 0..) |item, i| {
            if (item.asString()) |s| {
                if (std.mem.eql(u8, s, value)) return i;
            }
        }
        return null;
    }

    /// Saves the document to the original file path.
    pub fn save(self: *const Document) !void {
        const path = self.file_path orelse return error.NoFilePath;
        self.saveAs(path) catch |err| return err;
    }

    /// Saves the document to the specified file path.
    pub fn saveAs(self: *const Document, path: []const u8) !void {
        const output = stringify.stringify(self.allocator, &self.root, .{}) catch |err| return err;
        defer self.allocator.free(output);

        const file = std.fs.cwd().createFile(path, .{}) catch |err| return err;
        defer file.close();

        file.writeAll(output) catch |err| return err;
        file.writeAll("\n") catch |err| return err;
    }

    /// Atomically write the document to `path` by writing to a temporary file, then renaming.
    pub fn saveAsAtomic(self: *const Document, path: []const u8) !void {
        const output = stringify.stringify(self.allocator, &self.root, .{}) catch |err| return err;
        defer self.allocator.free(output);

        const tmp_path = std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path}) catch |err| return err;
        defer self.allocator.free(tmp_path);

        const tmp_file = std.fs.cwd().createFile(tmp_path, .{}) catch |err| return err;
        defer tmp_file.close();

        tmp_file.writeAll(output) catch |err| return err;
        tmp_file.writeAll("\n") catch |err| return err;

        std.fs.cwd().rename(tmp_path, path) catch |err| return err;

        // Update mtime if this document is associated with this path
        if (self.file_path) |fp| {
            if (std.mem.eql(u8, fp, path)) {
                // Best effort update mtime
                if (std.fs.cwd().openFile(path, .{})) |f| {
                    defer f.close();
                    if (f.stat()) |stat| {
                        // Cast away const to update mtime (mutable operation on logically const object if saving)
                        const self_mut = @constCast(self);
                        self_mut.last_mtime = stat.mtime;
                    } else |_| {}
                } else |_| {}
            }
        }
    }

    /// Save the document to the original file path, creating a backup of the previous file
    /// using the supplied extension (for example, ".bak") if it exists.
    pub fn saveWithBackup(self: *const Document, backup_ext: []const u8) !void {
        const path = self.file_path orelse return error.NoFilePath;

        const file_opt = std.fs.cwd().openFile(path, .{}) catch null;
        if (file_opt != null) {
            var file = file_opt.?;
            defer file.close();

            const backup = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ path, backup_ext }) catch |err| return err;
            defer self.allocator.free(backup);
            std.fs.cwd().rename(path, backup) catch |err| return err;
        }

        self.saveAs(path) catch |err| return err;
    }

    /// Save only if document content differs from existing file. Returns `true` if a write occurred.
    pub fn saveIfChanged(self: *const Document) !bool {
        const path = self.file_path orelse return error.NoFilePath;

        const new_output = stringify.stringify(self.allocator, &self.root, .{}) catch |err| return err;
        defer self.allocator.free(new_output);

        const file_opt = std.fs.cwd().openFile(path, .{}) catch null;
        if (file_opt == null) {
            self.saveAs(path) catch |err| return err;
            return true;
        }
        var file = file_opt.?;
        defer file.close();

        const existing = file.readToEndAlloc(self.allocator, 1024 * 1024 * 16) catch |err| return err;
        defer self.allocator.free(existing);

        // Normalize trailing newline when comparing (we write a trailing newline on save)
        const existing_trim = if (existing.len > 0 and existing[existing.len - 1] == '\n') existing[0 .. existing.len - 1] else existing;
        if (existing_trim.len == new_output.len and std.mem.eql(u8, existing_trim, new_output)) {
            return false;
        }

        self.saveAsAtomic(path) catch |err| return err;
        return true;
    }

    /// Deletes the backing file from disk.
    pub fn deleteFileOnDisk(self: *Document) !void {
        const path = self.file_path orelse return error.NoFilePath;
        std.fs.cwd().deleteFile(path) catch |err| return err;
        // We don't clear file_path, as the document might be saved again effectively "restoring" it or creating new.
        // But maybe we should? Generally if I delete the file, the doc is now "unsaved" / "new".
        // Let's keep file_path so save() re-creates it.
    }

    /// Renames the backing file on disk and updates file_path.
    pub fn renameFileOnDisk(self: *Document, new_path: []const u8) !void {
        const old_path = self.file_path orelse return error.NoFilePath;
        std.fs.cwd().rename(old_path, new_path) catch |err| return err;

        self.allocator.free(old_path);
        self.file_path = utils.dupeString(self.allocator, new_path) catch |err| return err;
    }

    /// Reloads the document from disk, discarding current changes.
    pub fn reload(self: *Document) !void {
        const path = self.file_path orelse return error.NoFilePath;

        const file = std.fs.cwd().openFile(path, .{}) catch |err| return err;
        defer file.close();

        const stat = file.stat() catch |err| return err;
        self.last_mtime = stat.mtime;

        const source = file.readToEndAlloc(self.allocator, 1024 * 1024 * 16) catch |err| return err;
        defer self.allocator.free(source);

        // Parse new root
        const new_root = parser.parse(self.allocator, source) catch |err| return err;

        // Replace old root
        self.root.deinit(self.allocator);
        self.root = new_root;
    }

    /// Checks if the file on disk has changed since load/save.
    pub fn hasChangedOnDisk(self: *const Document) bool {
        const path = self.file_path orelse return false;
        const file = std.fs.cwd().openFile(path, .{}) catch return false;
        defer file.close();

        const stat = file.stat() catch return false;
        return stat.mtime > self.last_mtime;
    }

    /// Returns the ZON string with default formatting.
    pub fn toString(self: *const Document) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{});
    }

    /// Serializes the document to a JSON string. Caller must free.
    pub fn toJsonString(self: *const Document) ![]u8 {
        return stringify.stringifyJson(self.allocator, &self.root);
    }

    /// Recursively search for the first occurrence of a key in the document.
    pub fn find(self: *const Document, key_to_find: []const u8) ?*const Value {
        return self.findInValue(&self.root, key_to_find);
    }

    /// Gets the string at path, or putting a default if missing.
    pub fn getOrPutString(self: *Document, path: []const u8, default: []const u8) ![]const u8 {
        if (self.getString(path)) |s| return s;
        self.setString(path, default) catch |err| return err;
        return self.getString(path).?;
    }

    /// Gets the int at path, or putting a default if missing.
    pub fn getOrPutInt(self: *Document, path: []const u8, default: i64) !i64 {
        if (self.getInt(path)) |i| return i;
        self.setInt(path, default) catch |err| return err;
        return default;
    }

    /// Gets the bool at path, or putting a default if missing.
    pub fn getOrPutBool(self: *Document, path: []const u8, default: bool) !bool {
        if (self.getBool(path)) |b| return b;
        self.setBool(path, default) catch |err| return err;
        return default;
    }

    /// Recursively search for all occurrences of a key in the document.
    /// Returns a list of paths. Caller must free results and each path.
    pub fn findAll(self: *const Document, key_to_find: []const u8) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |p| self.allocator.free(p);
            results.deinit(self.allocator);
        }

        self.findAllInValue(&self.root, key_to_find, "", &results) catch |err| return err;
        return results.toOwnedSlice(self.allocator);
    }

    fn findAllInValue(self: *const Document, val: *const Value, key_to_find: []const u8, prefix: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (val.*) {
            .object => |*o| {
                if (o.entries.getPtr(key_to_find)) |_| {
                    const path = if (prefix.len == 0)
                        self.allocator.dupe(u8, key_to_find) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, key_to_find }) catch |err| return err;
                    results.append(self.allocator, path) catch |err| return err;
                }
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const next_prefix = if (prefix.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(next_prefix);
                    self.findAllInValue(entry.value_ptr, key_to_find, next_prefix, results) catch |err| return err;
                }
            },
            .array => |*a| {
                for (a.items.items, 0..) |*item, i| {
                    const next_prefix = if (prefix.len == 0)
                        std.fmt.allocPrint(self.allocator, "[{d}]", .{i}) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i }) catch |err| return err;
                    defer self.allocator.free(next_prefix);
                    self.findAllInValue(item, key_to_find, next_prefix, results) catch |err| return err;
                }
            },
            else => {},
        }
    }

    fn findInValue(self: *const Document, val: *const Value, key_to_find: []const u8) ?*const Value {
        switch (val.*) {
            .object => |*o| {
                if (o.entries.getPtr(key_to_find)) |v| return v;
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    // Check if value is object or array before recursing to avoid extra calls?
                    // No, findInValue handles recursion.
                    if (self.findInValue(entry.value_ptr, key_to_find)) |v| return v;
                }
            },
            .array => |*a| {
                for (a.items.items) |*item| {
                    if (self.findInValue(item, key_to_find)) |v| return v;
                }
            },
            else => {},
        }
        return null;
    }

    /// Returns a stable 64-bit fingerprint (hash) of the document content.
    pub fn hash(self: *const Document) u64 {
        return self.root.hash();
    }

    /// Generates a checksum for the document using the provided algorithm.
    pub fn checksum(self: *const Document, comptime Algo: type, out: *[Algo.digest_length]u8) void {
        self.root.checksum(Algo, out);
    }

    /// Returns the size of the document in bytes when stringified with default options.
    pub fn byteSize(self: *const Document) !usize {
        const out = self.toString() catch |err| return err;
        defer self.allocator.free(out);
        return out.len;
    }

    /// Returns the size of the document in bytes when stringified in compact mode.
    pub fn compactSize(self: *const Document) !usize {
        const out = self.toCompactString() catch |err| return err;
        defer self.allocator.free(out);
        return out.len;
    }

    /// Compares this document with another and returns a list of paths
    /// that have different values. Caller must free results.
    pub fn diff(self: *const Document, other: *const Document) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |p| self.allocator.free(p);
            results.deinit(self.allocator);
        }

        self.diffRecursive(&self.root, &other.root, "", &results) catch |err| return err;
        return results.toOwnedSlice(self.allocator);
    }

    fn diffRecursive(self: *const Document, a: *const Value, b: *const Value, path: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        if (!a.eql(b)) {
            // If they are strictly different, check if they are both objects to recurse
            if (a.* == .object and b.* == .object) {
                const obj_a = a.asObject().?;
                const obj_b = b.asObject().?;

                // Check keys in A
                var it_a = obj_a.entries.iterator();
                while (it_a.next()) |entry| {
                    const next_path = if (path.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ path, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(next_path);

                    if (obj_b.get(entry.key_ptr.*)) |val_b| {
                        self.diffRecursive(entry.value_ptr, val_b, next_path, results) catch |err| return err;
                    } else {
                        results.append(self.allocator, self.allocator.dupe(u8, next_path) catch |err| return err) catch |err| return err;
                    }
                }

                // Check keys in B that are not in A
                var it_b = obj_b.entries.iterator();
                while (it_b.next()) |entry| {
                    if (!obj_a.entries.contains(entry.key_ptr.*)) {
                        const next_path = if (path.len == 0)
                            self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                        else
                            std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ path, entry.key_ptr.* }) catch |err| return err;
                        results.append(self.allocator, next_path) catch |err| return err;
                    }
                }
            } else {
                // Different types or both non-objects, and not equal
                results.append(self.allocator, self.allocator.dupe(u8, path) catch |err| return err) catch |err| return err;
            }
        }
    }

    /// Returns a flattened version of the document, where nested paths are
    /// converted to dot-notation keys (e.g., "db.port").
    /// Caller must free both the keys and the values.
    pub fn flatten(self: *const Document) !Document {
        var flat_doc = Document.initEmpty(self.allocator);
        errdefer flat_doc.deinit();

        self.flattenRecursive(&self.root, "", &flat_doc) catch |err| return err;
        return flat_doc;
    }

    fn flattenRecursive(self: *const Document, val: *const Value, path: []const u8, flat_doc: *Document) !void {
        switch (val.*) {
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_path = if (path.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ path, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(new_path);
                    self.flattenRecursive(entry.value_ptr, new_path, flat_doc) catch |err| return err;
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_path = if (path.len == 0)
                        std.fmt.allocPrint(self.allocator, "[{d}]", .{i}) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ path, i }) catch |err| return err;
                    defer self.allocator.free(new_path);
                    self.flattenRecursive(item, new_path, flat_doc) catch |err| return err;
                }
            },
            else => {
                if (path.len > 0) {
                    flat_doc.setValue(path, val.clone(self.allocator) catch |err| return err) catch |err| return err;
                }
            },
        }
    }

    /// Returns the ZON string with no indentation.
    pub fn toCompactString(self: *const Document) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{ .indent = 0 });
    }

    /// Returns the ZON string with custom indentation.
    pub fn toPrettyString(self: *const Document, indent_size: usize) ![]u8 {
        return stringify.stringify(self.allocator, &self.root, .{ .indent = indent_size });
    }

    /// Merges another document into this one recursively.
    pub fn mergeRecursive(self: *Document, other: *const Document) !void {
        self.mergeRecursiveValue(&self.root, &other.root) catch |err| return err;
    }

    fn mergeRecursiveValue(self: *Document, target: *Value, source: *const Value) !void {
        if (target.* == .object and source.* == .object) {
            var it = source.object.entries.iterator();
            while (it.next()) |entry| {
                const key = entry.key_ptr.*;
                if (target.object.get(key)) |existing| {
                    self.mergeRecursiveValue(existing, entry.value_ptr) catch |err| return err;
                } else {
                    const cloned = entry.value_ptr.clone(self.allocator) catch |err| return err;
                    target.object.put(key, cloned) catch |err| return err;
                }
            }
        } else {
            // Overwrite with cloned value
            const cloned = source.clone(self.allocator) catch |err| return err;
            target.deinit(self.allocator);
            target.* = cloned;
        }
    }

    /// Merges another document into this one. (Old shallow-like merge preserved for compatibility)
    pub fn merge(self: *Document, other: *const Document) !void {
        const other_obj = switch (other.root) {
            .object => |o| o,
            else => return,
        };

        const other_keys = other_obj.keys(self.allocator) catch |err| return err;
        defer self.allocator.free(other_keys);

        for (other_keys) |key| {
            if (other_obj.entries.get(key)) |other_val| {
                const cloned = other_val.clone(self.allocator) catch |err| return err;
                self.setValueByPath(key, cloned) catch |err| return err;
            }
        }
    }

    /// Creates a deep copy of the document.
    pub fn clone(self: *const Document) !Document {
        return .{
            .allocator = self.allocator,
            .root = self.root.clone(self.allocator) catch |err| return err,
            .file_path = if (self.file_path) |p| self.allocator.dupe(u8, p) catch |err| return err else null,
        };
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
        return utils.splitPath(self.allocator, path);
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
        const parts = self.splitPath(path) catch |err| return err;
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
                current.put(part, .{ .object = Value.Object.init(self.allocator) }) catch |err| return err;
                current = current.get(part).?.asObject().?;
            }
        }

        const last_key = parts[parts.len - 1];
        if (current.get(last_key)) |existing| {
            existing.deinit(self.allocator);
            existing.* = value;
        } else {
            current.put(last_key, value) catch |err| return err;
        }
    }

    fn findStringRecursive(self: *const Document, value: *const Value, prefix: []const u8, needle: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (value.*) {
            .string => |s| {
                if (std.mem.indexOf(u8, s, needle) != null) {
                    const path = self.allocator.dupe(u8, prefix) catch |err| return err;
                    results.append(self.allocator, path) catch |err| return err;
                }
            },
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findStringRecursive(entry.value_ptr, new_prefix, needle, results) catch |err| return err;
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findStringRecursive(item, new_prefix, needle, results) catch |err| return err;
                }
            },
            else => {},
        }
    }

    fn findExactRecursive(self: *const Document, value: *const Value, prefix: []const u8, needle: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (value.*) {
            .string => |s| {
                if (std.mem.eql(u8, s, needle)) {
                    const path = self.allocator.dupe(u8, prefix) catch |err| return err;
                    results.append(self.allocator, path) catch |err| return err;
                }
            },
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findExactRecursive(entry.value_ptr, new_prefix, needle, results) catch |err| return err;
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findExactRecursive(item, new_prefix, needle, results) catch |err| return err;
                }
            },
            else => {},
        }
    }

    fn findWhereRecursive(self: *const Document, value: *const Value, prefix: []const u8, predicate: *const fn (*const Value) bool, results: *std.ArrayListUnmanaged([]const u8)) !void {
        if (predicate(value)) {
            const path = self.allocator.dupe(u8, prefix) catch |err| return err;
            results.append(self.allocator, path) catch |err| return err;
        }

        switch (value.*) {
            .object => |o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const new_prefix = if (prefix.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch |err| return err
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findWhereRecursive(entry.value_ptr, new_prefix, predicate, results) catch |err| return err;
                }
            },
            .array => |a| {
                for (a.items.items, 0..) |*item, i| {
                    const new_prefix = std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i }) catch |err| return err;
                    defer self.allocator.free(new_prefix);
                    self.findWhereRecursive(item, new_prefix, predicate, results) catch |err| return err;
                }
            },
            else => {},
        }
    }

    fn replaceInValue(self: *Document, value: *Value, needle: []const u8, replacement: []const u8, mode: ReplaceMode) !usize {
        var replaced: usize = 0;

        switch (value.*) {
            .string => |s| {
                if (std.mem.eql(u8, s, needle)) {
                    self.allocator.free(s);
                    value.* = .{ .string = self.allocator.dupe(u8, replacement) catch |err| return err };
                    replaced += 1;
                }
            },
            .object => |*o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const count_val = self.replaceInValue(entry.value_ptr, needle, replacement, mode) catch |err| return err;
                    replaced += count_val;
                    if (mode == .first and replaced > 0) return replaced;
                }
            },
            .array => |*a| {
                for (a.items.items) |*item| {
                    const count_val = self.replaceInValue(item, needle, replacement, mode) catch |err| return err;
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

test "Document: array operations extended" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "two");
    try doc.insertStringIntoArray("arr", 0, "one");
    try doc.appendIntToArray("arr", 42);

    try std.testing.expectEqual(@as(usize, 3), doc.countAt("arr"));
    try std.testing.expectEqualStrings("one", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("two", doc.getArrayString("arr", 1).?);
    try std.testing.expectEqual(@as(usize, 1), doc.indexOf("arr", "two").?);

    try std.testing.expect(doc.removeFromArray("arr", 1));
    try std.testing.expectEqual(@as(usize, 2), doc.countAt("arr"));
    try std.testing.expectEqualStrings("one", doc.getArrayString("arr", 0).?);
}

test "Document: toStruct" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setInt("x", 100);
    try doc.setBool("y", true);

    const S = struct { x: i32, y: bool };
    const s = try doc.toStruct(S);
    try std.testing.expectEqual(@as(i32, 100), s.x);
    try std.testing.expectEqual(true, s.y);
}

test "Document: getOrPut" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try std.testing.expectEqualStrings("default", try doc.getOrPutString("s", "default"));
    try std.testing.expectEqualStrings("default", doc.getString("s").?);

    try std.testing.expectEqual(@as(i64, 42), try doc.getOrPutInt("i", 42));
    try std.testing.expectEqual(@as(i64, 42), doc.getInt("i").?);
}
