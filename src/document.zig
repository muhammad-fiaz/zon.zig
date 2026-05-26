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
    last_mtime: std.Io.Timestamp = .zero,

    /// Creates an empty document.
    pub fn initEmpty(allocator: Allocator) Document {
        return .{
            .allocator = allocator,
            .root = .{ .object = Value.Object.init(allocator) },
            .file_path = null,
            .last_mtime = .zero,
        };
    }

    /// Parses ZON content from source string.
    pub fn initFromSource(allocator: Allocator, source: []const u8) !Document {
        const root = try parser.parse(allocator, source);
        return .{
            .allocator = allocator,
            .root = root,
            .file_path = null,
            .last_mtime = .zero,
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
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        var file = try cwd.openFile(io, path, .{});
        defer file.close(io);

        const stat = try file.stat(io);
        const mtime = stat.mtime;

        const source = try cwd.readFileAlloc(io, path, allocator, std.Io.Limit.limited(1024 * 1024 * 16));
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

    /// Returns true if the value at the path is a string.
    pub fn isString(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.* == .string;
    }

    /// Returns true if the value at the path is a bool.
    pub fn isBool(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.* == .bool_val;
    }

    /// Returns true if the value at the path is an integer.
    pub fn isInt(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return switch (val.*) {
            .number => |n| n == .int,
            else => false,
        };
    }

    /// Returns true if the value at the path is a float.
    pub fn isFloat(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return switch (val.*) {
            .number => |n| n == .float,
            else => false,
        };
    }

    /// Returns true if the value at the path is a number (int or float).
    pub fn isNumber(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.* == .number;
    }

    /// Returns true if the value at the path is an object.
    pub fn isObject(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.* == .object;
    }

    /// Returns true if the value at the path is an array.
    pub fn isArray(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        return val.* == .array;
    }

    /// Alias for exists(). Returns true if the path has a value.
    pub fn isValue(self: *const Document, path: []const u8) bool {
        return self.exists(path);
    }

    /// Alias for exists(). Returns true if the key exists.
    pub fn isKey(self: *const Document, path: []const u8) bool {
        return self.exists(path);
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

    /// Applies a transform function to the string value at the path in-place.
    fn transformString(self: *Document, path: []const u8, comptime transform: fn (u8) u8) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        switch (val.*) {
            .string => |s| {
                const owned = try self.allocator.alloc(u8, s.len);
                for (s, 0..) |c, i| {
                    owned[i] = transform(c);
                }
                self.allocator.free(s);
                val.* = .{ .string = owned };
            },
            else => return error.NotAString,
        }
    }

    /// Converts the string value at the path to uppercase in-place.
    pub fn toUpper(self: *Document, path: []const u8) !void {
        try self.transformString(path, std.ascii.toUpper);
    }

    /// Converts the string value at the path to lowercase in-place.
    pub fn toLower(self: *Document, path: []const u8) !void {
        try self.transformString(path, std.ascii.toLower);
    }

    /// Returns true if the string value at the path is all uppercase.
    pub fn isUpperCase(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        const s = val.asString() orelse return false;
        for (s) |c| {
            if (!std.ascii.isUpper(c)) return false;
        }
        return true;
    }

    /// Returns true if the string value at the path is all lowercase.
    pub fn isLowerCase(self: *const Document, path: []const u8) bool {
        const val = self.getValueByPath(path) orelse return false;
        const s = val.asString() orelse return false;
        for (s) |c| {
            if (!std.ascii.isLower(c)) return false;
        }
        return true;
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
        const found_paths = self.findExact(needle) catch |err| return err;
        defer {
            for (found_paths) |p| self.allocator.free(p);
            self.allocator.free(found_paths);
        }

        if (found_paths.len == 0) return false;
        self.setString(found_paths[found_paths.len - 1], replacement) catch |err| return err;
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

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        var file = try cwd.createFile(io, path, .{});
        defer file.close(io);

        try file.writeStreamingAll(io, output);
        try file.writeStreamingAll(io, "\n");
    }

    /// Atomically write the document to `path` by writing to a temporary file, then renaming.
    pub fn saveAsAtomic(self: *const Document, path: []const u8) !void {
        const output = stringify.stringify(self.allocator, &self.root, .{}) catch |err| return err;
        defer self.allocator.free(output);

        const tmp_path = std.fmt.allocPrint(self.allocator, "{s}.tmp", .{path}) catch |err| return err;
        defer self.allocator.free(tmp_path);

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        var tmp_file = try cwd.createFile(io, tmp_path, .{});
        defer tmp_file.close(io);

        try tmp_file.writeStreamingAll(io, output);
        try tmp_file.writeStreamingAll(io, "\n");

        try cwd.rename(tmp_path, cwd, path, io);

        // Update mtime if this document is associated with this path
        if (self.file_path) |fp| {
            if (std.mem.eql(u8, fp, path)) {
                // Best effort update mtime
                if (cwd.openFile(io, path, .{})) |mut_f| {
                    var f = mut_f;
                    defer f.close(io);
                    if (f.stat(io)) |stat| {
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

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        const file_opt = cwd.openFile(io, path, .{}) catch null;
        if (file_opt) |mut_f| {
            var file = mut_f;
            defer file.close(io);

            const backup = std.fmt.allocPrint(self.allocator, "{s}{s}", .{ path, backup_ext }) catch |err| return err;
            defer self.allocator.free(backup);
            cwd.rename(path, cwd, backup, io) catch |err| return err;
        }

        self.saveAs(path) catch |err| return err;
    }

    /// Save only if document content differs from existing file. Returns `true` if a write occurred.
    pub fn saveIfChanged(self: *const Document) !bool {
        const path = self.file_path orelse return error.NoFilePath;

        const new_output = stringify.stringify(self.allocator, &self.root, .{}) catch |err| return err;
        defer self.allocator.free(new_output);

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        const file_opt = cwd.openFile(io, path, .{}) catch null;
        if (file_opt == null) {
            self.saveAs(path) catch |err| return err;
            return true;
        }
        var file = file_opt.?;
        defer file.close(io);

        const existing = cwd.readFileAlloc(io, path, self.allocator, std.Io.Limit.limited(1024 * 1024 * 16)) catch |err| return err;
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
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        cwd.deleteFile(io, path) catch |err| return err;
        // We don't clear file_path, as the document might be saved again effectively "restoring" it or creating new.
        // But maybe we should? Generally if I delete the file, the doc is now "unsaved" / "new".
        // Let's keep file_path so save() re-creates it.
    }

    /// Renames the backing file on disk and updates file_path.
    pub fn renameFileOnDisk(self: *Document, new_path: []const u8) !void {
        const old_path = self.file_path orelse return error.NoFilePath;
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        cwd.rename(old_path, cwd, new_path, io) catch |err| return err;

        self.allocator.free(old_path);
        self.file_path = utils.dupeString(self.allocator, new_path) catch |err| return err;
    }

    /// Reloads the document from disk, discarding current changes.
    pub fn reload(self: *Document) !void {
        const path = self.file_path orelse return error.NoFilePath;

        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        var file = try cwd.openFile(io, path, .{});
        defer file.close(io);

        const stat = file.stat(io) catch |err| return err;
        self.last_mtime = stat.mtime;

        const source = cwd.readFileAlloc(io, path, self.allocator, std.Io.Limit.limited(1024 * 1024 * 16)) catch |err| return err;
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
        var threaded: std.Io.Threaded = .init_single_threaded;
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();

        var file = cwd.openFile(io, path, .{}) catch return false;
        defer file.close(io);

        const stat = file.stat(io) catch return false;
        return stat.mtime.nanoseconds > self.last_mtime.nanoseconds;
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

    /// Returns all paths (dot-notation) in the document recursively.
    pub fn paths(self: *const Document) ![][]const u8 {
        var results: std.ArrayListUnmanaged([]const u8) = .empty;
        errdefer {
            for (results.items) |p| self.allocator.free(p);
            results.deinit(self.allocator);
        }
        try self.collectPaths(&self.root, "", &results);
        return results.toOwnedSlice(self.allocator);
    }

    fn collectPaths(self: *const Document, value: *const Value, prefix: []const u8, results: *std.ArrayListUnmanaged([]const u8)) !void {
        switch (value.*) {
            .object => |*o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const path = if (prefix.len == 0)
                        try self.allocator.dupe(u8, entry.key_ptr.*)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                    errdefer self.allocator.free(path);
                    try results.append(self.allocator, path);
                    try self.collectPaths(entry.value_ptr, path, results);
                }
            },
            .array => |*a| {
                for (a.items.items, 0..) |*item, i| {
                    const path = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    errdefer self.allocator.free(path);
                    try results.append(self.allocator, path);
                    try self.collectPaths(item, path, results);
                }
            },
            else => {},
        }
    }

    /// Walks all values depth-first, calling `visitor` for each.
    pub fn walk(self: *const Document, context: anytype, visitor: fn (ctx: @TypeOf(context), path: []const u8, value: *const Value) void) void {
        self.walkValue(&self.root, "", context, visitor);
    }

    fn walkValue(self: *const Document, value: *const Value, prefix: []const u8, context: anytype, visitor: fn (ctx: @TypeOf(context), path: []const u8, value: *const Value) void) void {
        visitor(context, prefix, value);
        switch (value.*) {
            .object => |*o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const next_prefix = if (prefix.len == 0)
                        self.allocator.dupe(u8, entry.key_ptr.*) catch return
                    else
                        std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* }) catch return;
                    defer self.allocator.free(next_prefix);
                    self.walkValue(entry.value_ptr, next_prefix, context, visitor);
                }
            },
            .array => |*a| {
                for (a.items.items, 0..) |*item, i| {
                    const next_prefix = std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i }) catch return;
                    defer self.allocator.free(next_prefix);
                    self.walkValue(item, next_prefix, context, visitor);
                }
            },
            else => {},
        }
    }

    /// Transforms all leaf values recursively using `mapper`.
    /// The mapper receives the path and a owned copy of each Value, and must return a new Value.
    pub fn mapValues(self: *Document, context: anytype, mapper: fn (ctx: @TypeOf(context), path: []const u8, value: Value) anyerror!Value) !void {
        self.root = try self.mapValue(self.root, "", context, mapper);
    }

    fn mapValue(self: *Document, value: Value, prefix: []const u8, context: anytype, mapper: fn (ctx: @TypeOf(context), path: []const u8, value: Value) anyerror!Value) anyerror!Value {
        var mutable = value;
        switch (mutable) {
            .object => |*o| {
                var new_obj = Value.Object.init(self.allocator);
                errdefer new_obj.deinit();

                var keys_buf: std.ArrayListUnmanaged([]const u8) = .empty;
                defer keys_buf.deinit(self.allocator);
                var kit = o.entries.keyIterator();
                while (kit.next()) |k| {
                    try keys_buf.append(self.allocator, k.*);
                }

                for (keys_buf.items) |key| {
                    const next_prefix = if (prefix.len == 0)
                        try self.allocator.dupe(u8, key)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, key });
                    defer self.allocator.free(next_prefix);

                    const entry = o.entries.fetchRemove(key).?;
                    const mapped_child = try self.mapValue(entry.value, next_prefix, context, mapper);
                    try new_obj.put(entry.key, mapped_child);
                    self.allocator.free(entry.key);
                }
                o.deinit();
                return try mapper(context, prefix, .{ .object = new_obj });
            },
            .array => |*a| {
                var new_arr = Value.Array.init(self.allocator);
                errdefer new_arr.deinit();
                for (a.items.items, 0..) |*item, i| {
                    const next_prefix = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    defer self.allocator.free(next_prefix);
                    var taken: Value = .null_val;
                    std.mem.swap(Value, item, &taken);
                    const mapped_child = try self.mapValue(taken, next_prefix, context, mapper);
                    try new_arr.append(mapped_child);
                }
                a.deinit();
                return try mapper(context, prefix, .{ .array = new_arr });
            },
            else => {
                var val = value;
                const copy_val = try val.clone(self.allocator);
                const result = try mapper(context, prefix, copy_val);
                val.deinit(self.allocator);
                return result;
            },
        }
    }

    /// Creates a new document containing only the specified paths.
    pub fn pick(self: *const Document, selected: []const []const u8) !Document {
        var new_doc = Document.initEmpty(self.allocator);
        errdefer new_doc.deinit();
        for (selected) |path| {
            if (self.getValueByPath(path)) |val| {
                const cloned = try val.clone(self.allocator);
                try new_doc.setValueByPath(path, cloned);
            }
        }
        return new_doc;
    }

    /// Creates a new document excluding the specified paths.
    pub fn omit(self: *const Document, excluded: []const []const u8) !Document {
        var new_doc = try self.clone();
        for (excluded) |path| {
            _ = new_doc.delete(path);
        }
        return new_doc;
    }

    /// Recursively sorts object keys. Use desc=true for descending order.
    fn sortKeysInternal(self: *Document, value: *Value, comptime desc: bool) void {
        const cmp = struct {
            fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                return if (desc) std.mem.order(u8, a, b) == .gt else std.mem.order(u8, a, b) == .lt;
            }
        }.lessThan;

        switch (value.*) {
            .object => |*o| {
                var new_entries: std.StringHashMapUnmanaged(Value) = .{};
                errdefer new_entries.deinit(self.allocator);

                var keys_buf: std.ArrayListUnmanaged([]const u8) = .empty;
                defer keys_buf.deinit(self.allocator);

                var it = o.entries.keyIterator();
                while (it.next()) |k| {
                    keys_buf.append(self.allocator, k.*) catch return;
                }

                std.mem.sort([]const u8, keys_buf.items, {}, cmp);

                for (keys_buf.items) |key| {
                    var entry = o.entries.fetchRemove(key).?;
                    new_entries.put(self.allocator, entry.key, entry.value) catch {
                        self.allocator.free(entry.key);
                        entry.value.deinit(self.allocator);
                        return;
                    };
                }

                o.entries.deinit(self.allocator);
                o.entries = new_entries;

                var child_it = o.entries.iterator();
                while (child_it.next()) |entry| {
                    self.sortKeysInternal(entry.value_ptr, desc);
                }
            },
            .array => |*a| {
                for (a.items.items) |*item| {
                    self.sortKeysInternal(item, desc);
                }
            },
            else => {},
        }
    }

    /// Recursively sorts all object keys in ascending alphabetical order.
    pub fn sortKeys(self: *Document) void {
        self.sortKeysInternal(&self.root, false);
    }

    /// Recursively sorts all object keys in descending alphabetical order.
    pub fn sortKeysDesc(self: *Document) void {
        self.sortKeysInternal(&self.root, true);
    }

    /// Sorts array elements at the path in ascending order (string comparison).
    pub fn sortArray(self: *Document, path: []const u8) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        std.mem.sort(Value, arr.items.items, {}, struct {
            fn lessThan(_: void, a: Value, b: Value) bool {
                const as = a.asString();
                const bs = b.asString();
                if (as != null and bs != null) {
                    return std.mem.order(u8, as.?, bs.?) == .lt;
                }
                return @intFromEnum(std.meta.activeTag(a)) < @intFromEnum(std.meta.activeTag(b));
            }
        }.lessThan);
    }

    /// Reverses array elements at the path in-place.
    pub fn reverseArray(self: *Document, path: []const u8) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        var i: usize = 0;
        var j: usize = arr.items.items.len;
        while (i < j) {
            j -= 1;
            std.mem.swap(Value, &arr.items.items[i], &arr.items.items[j]);
            i += 1;
        }
    }

    /// Truncates the array at the path to the given new length.
    /// Elements beyond new_len are deinitialized.
    pub fn truncate(self: *Document, path: []const u8, new_len: usize) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        const old_len = arr.items.items.len;
        if (new_len >= old_len) return;
        while (arr.items.items.len > new_len) {
            var item = arr.pop().?;
            item.deinit(self.allocator);
        }
    }

    /// Drops the first n elements from the array at the path.
    pub fn dropFirst(self: *Document, path: []const u8, n: usize) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        const drop_count = @min(n, arr.items.items.len);
        var i: usize = 0;
        while (i < drop_count) : (i += 1) {
            var item = arr.items.orderedRemove(0);
            item.deinit(self.allocator);
        }
    }

    /// Drops the last n elements from the array at the path.
    pub fn dropLast(self: *Document, path: []const u8, n: usize) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        const drop_count = @min(n, arr.items.items.len);
        var i: usize = 0;
        while (i < drop_count) : (i += 1) {
            var item = arr.pop().?;
            item.deinit(self.allocator);
        }
    }

    /// Returns a pointer to the first element of the array at the path.
    pub fn first(self: *const Document, path: []const u8) ?*const Value {
        const val = self.getValueByPath(path) orelse return null;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return null,
        };
        return arr.get(0);
    }

    /// Returns a pointer to the last element of the array at the path.
    pub fn last(self: *const Document, path: []const u8) ?*const Value {
        const val = self.getValueByPath(path) orelse return null;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return null,
        };
        const arr_len = arr.len();
        if (arr_len == 0) return null;
        return arr.get(arr_len - 1);
    }

    /// Removes all null values from the array at the path in-place.
    pub fn compact(self: *Document, path: []const u8) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        var i: usize = 0;
        while (i < arr.items.items.len) {
            if (arr.items.items[i] == .null_val) {
                var item = arr.items.orderedRemove(i);
                item.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }

    /// Removes duplicate values from the array at the path in-place (string comparison).
    pub fn unique(self: *Document, path: []const u8) !void {
        const val = self.getMutableValueByPath(path) orelse return error.PathNotFound;
        const arr = val.asArray() orelse return error.NotAnArray;
        var i: usize = 0;
        while (i < arr.items.items.len) {
            const a = &arr.items.items[i];
            var dup = false;
            var j: usize = 0;
            while (j < i) {
                if (a.eql(&arr.items.items[j])) {
                    dup = true;
                    break;
                }
                j += 1;
            }
            if (dup) {
                var item = arr.items.orderedRemove(i);
                item.deinit(self.allocator);
            } else {
                i += 1;
            }
        }
    }

    /// Creates a new document containing only paths where the predicate returns true.
    /// The predicate receives each path and value.
    pub fn filter(self: *const Document, allocator: Allocator, context: anytype, predicate: fn (ctx: @TypeOf(context), path: []const u8, value: *const Value) bool) !Document {
        var new_doc = Document.initEmpty(allocator);
        errdefer new_doc.deinit();
        try self.filterRecursive(&self.root, "", context, predicate, &new_doc);
        return new_doc;
    }

    fn filterRecursive(self: *const Document, value: *const Value, prefix: []const u8, context: anytype, predicate: fn (ctx: @TypeOf(context), path: []const u8, value: *const Value) bool, result: *Document) !void {
        if (predicate(context, prefix, value)) {
            const cloned = try value.clone(self.allocator);
            if (prefix.len == 0) {
                result.root.deinit(result.allocator);
                result.root = cloned;
            } else {
                try result.setValueByPath(prefix, cloned);
            }
            return;
        }
        switch (value.*) {
            .object => |*o| {
                var it = o.entries.iterator();
                while (it.next()) |entry| {
                    const next_prefix = if (prefix.len == 0)
                        try self.allocator.dupe(u8, entry.key_ptr.*)
                    else
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, entry.key_ptr.* });
                    defer self.allocator.free(next_prefix);
                    try self.filterRecursive(entry.value_ptr, next_prefix, context, predicate, result);
                }
            },
            .array => |*a| {
                for (a.items.items, 0..) |*item, i| {
                    const next_prefix = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ prefix, i });
                    defer self.allocator.free(next_prefix);
                    try self.filterRecursive(item, next_prefix, context, predicate, result);
                }
            },
            else => {},
        }
    }

    /// Iterates over all values with a callback. Returns void.
    pub fn forEach(self: *const Document, context: anytype, callback: fn (ctx: @TypeOf(context), path: []const u8, value: *const Value) void) void {
        self.walk(context, callback);
    }

    /// Returns true if all elements in the array at the path satisfy the predicate.
    pub fn every(self: *const Document, path: []const u8, predicate: *const fn (*const Value) bool) bool {
        const val = self.getValueByPath(path) orelse return false;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return false,
        };
        for (arr.items.items) |*item| {
            if (!predicate(item)) return false;
        }
        return true;
    }

    /// Returns true if any element in the array at the path satisfies the predicate.
    pub fn some(self: *const Document, path: []const u8, predicate: *const fn (*const Value) bool) bool {
        const val = self.getValueByPath(path) orelse return false;
        const arr = switch (val.*) {
            .array => |a| a,
            else => return false,
        };
        for (arr.items.items) |*item| {
            if (predicate(item)) return true;
        }
        return false;
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
    _ = std.Io.Dir.cwd().deleteFile(std.testing.io, path) catch null;

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
    _ = std.Io.Dir.cwd().deleteFile(std.testing.io, path) catch null;
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

test "Document: paths" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("server.host", "localhost");
    try doc.setInt("server.port", 8080);
    try doc.setBool("ssl.enabled", true);

    const all_paths = try doc.paths();
    defer {
        for (all_paths) |p| allocator.free(p);
        allocator.free(all_paths);
    }

    try std.testing.expectEqual(@as(usize, 5), all_paths.len);
    var found: usize = 0;
    for (all_paths) |p| {
        if (std.mem.eql(u8, p, "server.host") or std.mem.eql(u8, p, "server.port") or std.mem.eql(u8, p, "ssl.enabled")) {
            found += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 3), found);
}

test "Document: walk" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "hello");
    try doc.setBool("b", true);
    try doc.setInt("c", 42);

    var count: usize = 0;
    const Context = struct {
        count: *usize,
    };
    var ctx = Context{ .count = &count };

    doc.walk(&ctx, struct {
        fn visit(c: *Context, path: []const u8, value: *const Value) void {
            _ = path;
            _ = value;
            c.count.* += 1;
        }
    }.visit);

    try std.testing.expectEqual(@as(usize, 4), count); // root object + 3 values
}

test "Document: mapValues transforms strings" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "hello");
    try doc.setString("b", "world");

    const Context = struct {
        doc: *Document,
        allocator: std.mem.Allocator,
        fn map(c: *@This(), path: []const u8, value: Value) anyerror!Value {
            _ = path;
            if (value == .string) {
                var owned = value;
                const result_str = try std.ascii.allocUpperString(c.allocator, owned.string);
                owned.deinit(c.allocator);
                return Value{ .string = result_str };
            }
            return value;
        }
    };

    var ctx = Context{ .doc = &doc, .allocator = allocator };
    try doc.mapValues(&ctx, Context.map);

    try std.testing.expectEqualStrings("HELLO", doc.getString("a").?);
    try std.testing.expectEqualStrings("WORLD", doc.getString("b").?);
}

test "Document: pick" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try doc.setInt("version", 1);
    try doc.setBool("active", true);

    var picked = try doc.pick(&.{ "name", "version" });
    defer picked.deinit();

    try std.testing.expectEqualStrings("test", picked.getString("name").?);
    try std.testing.expectEqual(@as(i64, 1), picked.getInt("version").?);
    try std.testing.expect(!picked.exists("active"));
}

test "Document: omit" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try doc.setInt("version", 1);
    try doc.setBool("active", true);

    var omitted = try doc.omit(&.{"version"});
    defer omitted.deinit();

    try std.testing.expectEqualStrings("test", omitted.getString("name").?);
    try std.testing.expect(!omitted.exists("version"));
    try std.testing.expectEqual(true, omitted.getBool("active").?);
}

test "Document: sortKeys" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    var obj = Value.Object.init(allocator);
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("m", .{ .string = try allocator.dupe(u8, "middle") });

    var inner_obj = Value.Object.init(allocator);
    try inner_obj.put("y", .{ .string = try allocator.dupe(u8, "inner_last") });
    try inner_obj.put("b", .{ .string = try allocator.dupe(u8, "inner_first") });
    try obj.put("nested", .{ .object = inner_obj });

    doc.root = .{ .object = obj };

    doc.sortKeys();

    // Verify values are preserved
    try std.testing.expectEqualStrings("first", doc.getString("a").?);
    try std.testing.expectEqualStrings("last", doc.getString("z").?);
    try std.testing.expectEqualStrings("middle", doc.getString("m").?);
    try std.testing.expectEqualStrings("inner_first", doc.getString("nested.b").?);
    try std.testing.expectEqualStrings("inner_last", doc.getString("nested.y").?);
}

test "Document: type checking isString isBool isInt isFloat isNumber isObject isArray" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("s", "hello");
    try doc.setBool("b", true);
    try doc.setInt("i", 42);
    try doc.setFloat("f", 3.14);
    try doc.setObject("o");
    try doc.setArray("a");

    try std.testing.expect(doc.isString("s"));
    try std.testing.expect(!doc.isString("b"));
    try std.testing.expect(doc.isBool("b"));
    try std.testing.expect(!doc.isBool("s"));
    try std.testing.expect(doc.isInt("i"));
    try std.testing.expect(!doc.isInt("f"));
    try std.testing.expect(doc.isFloat("f"));
    try std.testing.expect(!doc.isFloat("i"));
    try std.testing.expect(doc.isNumber("i"));
    try std.testing.expect(doc.isNumber("f"));
    try std.testing.expect(!doc.isNumber("s"));
    try std.testing.expect(doc.isObject("o"));
    try std.testing.expect(!doc.isObject("s"));
    try std.testing.expect(doc.isArray("a"));
    try std.testing.expect(!doc.isArray("s"));
}

test "Document: isValue and isKey aliases" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try std.testing.expect(doc.isValue("name"));
    try std.testing.expect(doc.isKey("name"));
    try std.testing.expect(!doc.isValue("nonexistent"));
    try std.testing.expect(!doc.isKey("nonexistent"));
}

test "Document: toUpper and toLower" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "Hello World");
    try doc.toUpper("name");
    try std.testing.expectEqualStrings("HELLO WORLD", doc.getString("name").?);

    try doc.toLower("name");
    try std.testing.expectEqualStrings("hello world", doc.getString("name").?);
}

test "Document: isUpperCase and isLowerCase" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("upper", "HELLO");
    try doc.setString("lower", "hello");
    try doc.setString("mixed", "Hello");

    try std.testing.expect(doc.isUpperCase("upper"));
    try std.testing.expect(!doc.isUpperCase("lower"));
    try std.testing.expect(!doc.isUpperCase("mixed"));

    try std.testing.expect(doc.isLowerCase("lower"));
    try std.testing.expect(!doc.isLowerCase("upper"));
    try std.testing.expect(!doc.isLowerCase("mixed"));
}

test "Document: sortKeysDesc" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    var obj = Value.Object.init(allocator);
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("m", .{ .string = try allocator.dupe(u8, "middle") });
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });

    doc.root = .{ .object = obj };
    doc.sortKeysDesc();

    try std.testing.expectEqualStrings("first", doc.getString("a").?);
    try std.testing.expectEqualStrings("middle", doc.getString("m").?);
    try std.testing.expectEqualStrings("last", doc.getString("z").?);
}

test "Document: sortArray" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "zebra");
    try doc.appendToArray("arr", "apple");
    try doc.appendToArray("arr", "monkey");

    try doc.sortArray("arr");

    try std.testing.expectEqualStrings("apple", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("monkey", doc.getArrayString("arr", 1).?);
    try std.testing.expectEqualStrings("zebra", doc.getArrayString("arr", 2).?);
}

test "Document: reverseArray" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "one");
    try doc.appendToArray("arr", "two");
    try doc.appendToArray("arr", "three");

    try doc.reverseArray("arr");

    try std.testing.expectEqualStrings("three", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("two", doc.getArrayString("arr", 1).?);
    try std.testing.expectEqualStrings("one", doc.getArrayString("arr", 2).?);
}

test "Document: truncate array" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "a");
    try doc.appendToArray("arr", "b");
    try doc.appendToArray("arr", "c");
    try doc.appendToArray("arr", "d");

    try doc.truncate("arr", 2);
    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("arr").?);
    try std.testing.expectEqualStrings("a", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("arr", 1).?);
}

test "Document: dropFirst and dropLast" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "a");
    try doc.appendToArray("arr", "b");
    try doc.appendToArray("arr", "c");
    try doc.appendToArray("arr", "d");
    try doc.appendToArray("arr", "e");

    try doc.dropFirst("arr", 2);
    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("arr").?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("arr", 0).?);

    try doc.dropLast("arr", 1);
    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("arr").?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("d", doc.getArrayString("arr", 1).?);
}

test "Document: forEach iterates all values" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("a", "hello");
    try doc.setBool("b", true);

    var count: usize = 0;
    const Context = struct {
        count: *usize,
    };
    var ctx = Context{ .count = &count };
    doc.forEach(&ctx, struct {
        fn cb(c: *Context, _: []const u8, _: *const Value) void {
            c.count.* += 1;
        }
    }.cb);

    try std.testing.expectEqual(@as(usize, 3), count); // root object + 2 values
}

test "Document: every and some on array" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("nums");
    try doc.appendIntToArray("nums", 2);
    try doc.appendIntToArray("nums", 4);
    try doc.appendIntToArray("nums", 6);

    const Predicates = struct {
        fn isEven(v: *const Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) == 0;
        }
        fn isOdd(v: *const Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) != 0;
        }
    };

    try std.testing.expect(doc.every("nums", Predicates.isEven));
    try std.testing.expect(!doc.some("nums", Predicates.isOdd));
}

test "Document: filter" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");
    try doc.setInt("version", 1);
    try doc.setBool("active", true);

    const Context = struct {
        fn isString(_: *@This(), _: []const u8, value: *const Value) bool {
            return value.* == .string;
        }
    };

    var ctx = Context{};
    var filtered = try doc.filter(allocator, &ctx, Context.isString);
    defer filtered.deinit();

    try std.testing.expectEqualStrings("test", filtered.getString("name").?);
    try std.testing.expect(!filtered.exists("version"));
    try std.testing.expect(!filtered.exists("active"));
}

test "Document: first and last on array" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "first");
    try doc.appendToArray("arr", "middle");
    try doc.appendToArray("arr", "last");

    try std.testing.expectEqualStrings("first", doc.first("arr").?.asString().?);
    try std.testing.expectEqualStrings("last", doc.last("arr").?.asString().?);
}

test "Document: compact removes nulls from array" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "a");
    try doc.setValue("arr[1]", .null_val);
    try doc.appendToArray("arr", "b");
    try doc.setValue("arr[3]", .null_val);
    try doc.appendToArray("arr", "c");

    try doc.compact("arr");

    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("arr").?);
    try std.testing.expectEqualStrings("a", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("arr", 1).?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("arr", 2).?);
}

test "Document: unique removes duplicates from array" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("arr");
    try doc.appendToArray("arr", "a");
    try doc.appendToArray("arr", "b");
    try doc.appendToArray("arr", "a");
    try doc.appendToArray("arr", "c");
    try doc.appendToArray("arr", "b");

    try doc.unique("arr");

    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("arr").?);
    try std.testing.expectEqualStrings("a", doc.getArrayString("arr", 0).?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("arr", 1).?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("arr", 2).?);
}

test "Document: nested path validation" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("server.host", "localhost");
    try doc.setInt("server.port", 8080);
    try doc.setBool("server.ssl.enabled", true);
    try doc.setObject("server.tags");
    try doc.setArray("server.mirrors");

    try std.testing.expect(doc.isString("server.host"));
    try std.testing.expect(doc.isInt("server.port"));
    try std.testing.expect(doc.isBool("server.ssl.enabled"));
    try std.testing.expect(doc.isObject("server.tags"));
    try std.testing.expect(doc.isArray("server.mirrors"));
    try std.testing.expect(!doc.isString("server.port"));
    try std.testing.expect(!doc.isArray("server.host"));
}

test "Document: nested toUpper and toLower" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("config.name", "MyApp");
    try doc.toUpper("config.name");
    try std.testing.expectEqualStrings("MYAPP", doc.getString("config.name").?);
    try std.testing.expect(doc.isUpperCase("config.name"));

    try doc.toLower("config.name");
    try std.testing.expectEqualStrings("myapp", doc.getString("config.name").?);
    try std.testing.expect(doc.isLowerCase("config.name"));
}

test "Document: nested sortArray and reverseArray" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("config.tags");
    try doc.appendToArray("config.tags", "z");
    try doc.appendToArray("config.tags", "a");
    try doc.appendToArray("config.tags", "m");

    try doc.sortArray("config.tags");
    try std.testing.expectEqualStrings("a", doc.getArrayString("config.tags", 0).?);
    try std.testing.expectEqualStrings("m", doc.getArrayString("config.tags", 1).?);
    try std.testing.expectEqualStrings("z", doc.getArrayString("config.tags", 2).?);

    try doc.reverseArray("config.tags");
    try std.testing.expectEqualStrings("z", doc.getArrayString("config.tags", 0).?);
}

test "Document: nested truncate and drop" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("config.items");
    try doc.appendToArray("config.items", "a");
    try doc.appendToArray("config.items", "b");
    try doc.appendToArray("config.items", "c");
    try doc.appendToArray("config.items", "d");
    try doc.appendToArray("config.items", "e");

    try doc.dropFirst("config.items", 2);
    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("config.items").?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("config.items", 0).?);

    try doc.truncate("config.items", 1);
    try std.testing.expectEqual(@as(usize, 1), doc.arrayLen("config.items").?);
    try std.testing.expectEqualStrings("c", doc.getArrayString("config.items", 0).?);
}

test "Document: nested compact and unique" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("data.vals");
    try doc.appendToArray("data.vals", "a");
    try doc.setValue("data.vals[1]", .null_val);
    try doc.appendToArray("data.vals", "a");
    try doc.appendToArray("data.vals", "b");
    try doc.setValue("data.vals[4]", .null_val);

    try doc.compact("data.vals");
    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("data.vals").?);

    try doc.unique("data.vals");
    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("data.vals").?);
    try std.testing.expectEqualStrings("a", doc.getArrayString("data.vals", 0).?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("data.vals", 1).?);
}

test "Document: nested every and some" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setArray("nums");
    try doc.appendIntToArray("nums", 2);
    try doc.appendIntToArray("nums", 4);
    try doc.appendIntToArray("nums", 6);

    const NestedPred = struct {
        fn isEven(v: *const Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) == 0;
        }
        fn isOdd(v: *const Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) != 0;
        }
    };

    try std.testing.expect(doc.every("nums", NestedPred.isEven));
    try std.testing.expect(!doc.some("nums", NestedPred.isOdd));
}

test "Document: nested sortKeys" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    var obj = Value.Object.init(allocator);
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("m", .{ .string = try allocator.dupe(u8, "middle") });

    doc.root = .{ .object = obj };
    doc.sortKeysDesc();

    try std.testing.expectEqualStrings("first", doc.getString("a").?);
    try std.testing.expectEqualStrings("middle", doc.getString("m").?);
    try std.testing.expectEqualStrings("last", doc.getString("z").?);
}

test "Document: nested filter" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try doc.setString("app.name", "test");
    try doc.setInt("app.version", 1);
    try doc.setBool("app.active", true);

    const Ctx = struct {
        fn isString(_: *@This(), _: []const u8, value: *const Value) bool {
            return value.* == .string;
        }
    };

    var ctx = Ctx{};
    var filtered = try doc.filter(allocator, &ctx, Ctx.isString);
    defer filtered.deinit();

    try std.testing.expectEqualStrings("test", filtered.getString("app.name").?);
    try std.testing.expect(!filtered.exists("app.version"));
    try std.testing.expect(!filtered.exists("app.active"));
}
