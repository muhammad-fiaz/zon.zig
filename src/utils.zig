//! Internal utilities for zon.zig

const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Dir = Io.Dir;

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

/// String less-than comparator for sorting.
pub fn stringLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.order(u8, a, b) == .lt;
}

/// Minimal growable byte buffer for building strings.
pub const Buffer = struct {
    data: std.ArrayListUnmanaged(u8) = .{},

    pub fn init() Buffer {
        return .{};
    }

    pub fn deinit(self: *Buffer, allocator: std.mem.Allocator) void {
        self.data.deinit(allocator);
    }

    pub fn append(self: *Buffer, allocator: std.mem.Allocator, byte: u8) !void {
        try self.data.append(allocator, byte);
    }

    pub fn appendSlice(self: *Buffer, allocator: std.mem.Allocator, bytes: []const u8) !void {
        try self.data.appendSlice(allocator, bytes);
    }

    pub fn appendNTimes(self: *Buffer, allocator: std.mem.Allocator, byte: u8, count: usize) !void {
        try self.data.appendNTimes(allocator, byte, count);
    }

    pub fn toOwnedSlice(self: *Buffer, allocator: std.mem.Allocator) ![]u8 {
        return self.data.toOwnedSlice(allocator);
    }
};

/// Cross-platform file I/O wrappers for Zig 0.16's std.Io API.
/// Replaces the removed `std.fs.cwd()` pattern.
pub const fs = struct {
    pub fn cwd() Dir {
        return Dir.cwd();
    }

    pub fn io() Io {
        return Io.Threaded.global_single_threaded.io();
    }

    pub fn openFile(path: []const u8, options: Dir.OpenFileOptions) Io.File.OpenError!Io.File {
        return Dir.openFile(cwd(), io(), path, options);
    }

    pub fn createFile(path: []const u8, flags: Dir.CreateFileOptions) Io.File.OpenError!Io.File {
        return Dir.createFile(cwd(), io(), path, flags);
    }

    pub fn deleteFile(path: []const u8) Dir.DeleteFileError!void {
        return Dir.deleteFile(cwd(), io(), path);
    }

    pub fn rename(old_path: []const u8, new_path: []const u8) Dir.RenameError!void {
        return Dir.rename(cwd(), old_path, cwd(), new_path, io());
    }

    pub fn access(path: []const u8, options: Dir.AccessOptions) Dir.AccessError!void {
        return Dir.access(cwd(), io(), path, options);
    }

    pub fn readFileAlloc(gpa: Allocator, path: []const u8, limit: Io.Limit) Dir.ReadFileAllocError![]u8 {
        return Dir.readFileAlloc(cwd(), io(), path, gpa, limit);
    }

    pub fn readFile(path: []const u8, buffer: []u8) Dir.ReadFileError![]u8 {
        return Dir.readFile(cwd(), io(), path, buffer);
    }

    pub fn writeFile(file: Io.File, data: []const u8) Io.File.Writer.Error!void {
        return Io.File.writeStreamingAll(file, io(), data);
    }

    pub fn closeFile(file: Io.File) void {
        file.close(io());
    }

    pub fn copyFile(src_path: []const u8, dest_path: []const u8, options: Dir.CopyFileOptions) Dir.CopyFileError!void {
        return Dir.copyFile(cwd(), src_path, cwd(), dest_path, io(), options);
    }

    pub fn fileStat(file: Io.File) Io.File.StatError!Io.File.Stat {
        return file.stat(io());
    }
};
