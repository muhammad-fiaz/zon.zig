//! zon.zig - A document-based ZON library for Zig.
//!
//! Unlike `std.zon` which parses ZON directly into typed Zig structures,
//! zon.zig maintains an in-memory document tree that you can query, modify, and serialize.
//! This makes it ideal for configuration file editing, dynamic access, and find/replace operations.
//!
//! See: https://codeberg.org/ziglang/zig/src/branch/master/lib/std/zon for std.zon reference.
//!
//! Repository: https://github.com/muhammad-fiaz/zon.zig

const std = @import("std");
const Allocator = std.mem.Allocator;
const document = @import("document.zig");

// File related errors used by higher-level utilities
pub const FileError = error{FileAlreadyExists};
pub const version_info = @import("version.zig");
pub const update_checker = @import("update_checker.zig");
pub const Value = @import("value.zig").Value;

pub const Document = document.Document;
pub const version = version_info.version;

/// Disables update checking.
pub fn disableUpdateCheck() void {
    update_checker.disableUpdateCheck();
}

/// Enables update checking.
pub fn enableUpdateCheck() void {
    update_checker.enableUpdateCheck();
}

/// Returns true if update checking is enabled.
pub fn isUpdateCheckEnabled() bool {
    return update_checker.isUpdateCheckEnabled();
}

/// Checks for updates and prints notification if available.
pub fn checkForUpdates(allocator: Allocator) void {
    update_checker.checkAndNotify(allocator);
}

/// Opens an existing ZON file.
pub fn open(allocator: Allocator, file_path: []const u8) !Document {
    return Document.initFromFile(allocator, file_path);
}

/// Creates a new empty document.
pub fn create(allocator: Allocator) Document {
    return Document.initEmpty(allocator);
}

/// Parses ZON from a string.
pub fn parse(allocator: Allocator, source: []const u8) !Document {
    return Document.initFromSource(allocator, source);
}

/// Deletes a file.
pub fn deleteFile(file_path: []const u8) !void {
    try std.fs.cwd().deleteFile(file_path);
}

/// Returns true if the file exists.
pub fn fileExists(file_path: []const u8) bool {
    std.fs.cwd().access(file_path, .{}) catch return false;
    return true;
}

/// Copy a file, with optional overwrite behaviour.
pub fn copyFile(source_path: []const u8, dest_path: []const u8, overwrite: bool) !void {
    if (!overwrite) {
        const dest_file_opt = std.fs.cwd().openFile(dest_path, .{}) catch null;
        if (dest_file_opt != null) {
            var dest_file = dest_file_opt.?;
            defer dest_file.close();
            return FileError.FileAlreadyExists;
        }
    }
    try std.fs.cwd().copyFile(source_path, std.fs.cwd(), dest_path, .{});
}

/// Move (rename) a file, with optional overwrite.
pub fn moveFile(old_path: []const u8, new_path: []const u8, overwrite: bool) !void {
    if (overwrite) {
        _ = std.fs.cwd().deleteFile(new_path) catch null;
    } else {
        const existing_file_opt = std.fs.cwd().openFile(new_path, .{}) catch null;
        if (existing_file_opt != null) {
            var existing_file = existing_file_opt.?;
            defer existing_file.close();
            return FileError.FileAlreadyExists;
        }
    }
    try std.fs.cwd().rename(old_path, new_path);
}

/// Read a file into an allocator-owned buffer (caller must free).
pub fn readFile(allocator: Allocator, path: []const u8) ![]u8 {
    const f = try std.fs.cwd().openFile(path, .{});
    defer f.close();
    return try f.readToEndAlloc(allocator, 1024 * 1024 * 64);
}

/// Write data to `path` atomically: write to a temporary file and rename.
pub fn writeFileAtomic(allocator: Allocator, path: []const u8, data: []const u8) !void {
    const tmp = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(tmp);

    const f = try std.fs.cwd().createFile(tmp, .{});
    defer f.close();

    try f.writeAll(data);
    try f.writeAll("\n");

    try std.fs.cwd().rename(tmp, path);
}

test "create and set values" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setBool("private", true);
    try doc.setInt("version", 1);
    try doc.setFloat("score", 3.14);

    try std.testing.expectEqualStrings("myapp", doc.getString("name").?);
    try std.testing.expectEqual(true, doc.getBool("private").?);
    try std.testing.expectEqual(@as(i64, 1), doc.getInt("version").?);
    try std.testing.expectApproxEqAbs(@as(f64, 3.14), doc.getFloat("score").?, 0.001);
}

test "nested paths" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("dependencies.foo.path", "../foo");
    try doc.setString("dependencies.foo.version", "1.0.0");
    try doc.setString("dependencies.bar.path", "../bar");

    try std.testing.expectEqualStrings("../foo", doc.getString("dependencies.foo.path").?);
    try std.testing.expectEqualStrings("1.0.0", doc.getString("dependencies.foo.version").?);
    try std.testing.expectEqualStrings("../bar", doc.getString("dependencies.bar.path").?);
}

test "delete values" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setBool("private", true);

    try std.testing.expect(doc.getString("name") != null);
    try std.testing.expect(doc.delete("name"));
    try std.testing.expect(doc.getString("name") == null);
}

test "parse zon source" {
    const allocator = std.testing.allocator;

    const source =
        \\.{
        \\    .name = "test",
        \\    .version = 123,
        \\    .enabled = true,
        \\}
    ;

    var doc = try parse(allocator, source);
    defer doc.deinit();

    try std.testing.expectEqualStrings("test", doc.getString("name").?);
    try std.testing.expectEqual(@as(i64, 123), doc.getInt("version").?);
    try std.testing.expectEqual(true, doc.getBool("enabled").?);
}

test "parse build.zig.zon format" {
    const allocator = std.testing.allocator;

    const source =
        \\.{
        \\    .name = .zon,
        \\    .version = "0.0.3",
        \\    .fingerprint = 0xee480fa30d50cbf6,
        \\    .minimum_zig_version = "0.15.0",
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\    },
        \\}
    ;

    var doc = try parse(allocator, source);
    defer doc.deinit();

    try std.testing.expectEqualStrings("zon", doc.getString("name").?);
    try std.testing.expectEqualStrings("0.0.3", doc.getString("version").?);
    try std.testing.expect(doc.getUint("fingerprint") != null);
    try std.testing.expectEqual(@as(usize, 3), doc.arrayLen("paths").?);
    try std.testing.expectEqualStrings("build.zig", doc.getArrayString("paths", 0).?);
}

test "missing paths return null" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try std.testing.expect(doc.getString("nonexistent") == null);
    try std.testing.expect(doc.getBool("nonexistent") == null);
    try std.testing.expect(doc.getInt("nonexistent") == null);
}

test "type mismatch returns null" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "test");

    try std.testing.expect(doc.getString("name") != null);
    try std.testing.expect(doc.getBool("name") == null);
    try std.testing.expect(doc.getInt("name") == null);
}

test "stringify document" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setBool("private", true);

    const output = try doc.toString();
    defer allocator.free(output);

    try std.testing.expect(std.mem.indexOf(u8, output, ".name") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "\"myapp\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, ".private") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "true") != null);
}

test "version info" {
    try std.testing.expectEqualStrings("0.0.3", version);
}

test "find and replace" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("a", "hello");
    try doc.setString("b", "hello");
    try doc.setString("c", "world");

    const count_val = try doc.replaceAll("hello", "goodbye");
    try std.testing.expectEqual(@as(usize, 2), count_val);

    try std.testing.expectEqualStrings("goodbye", doc.getString("a").?);
    try std.testing.expectEqualStrings("goodbye", doc.getString("b").?);
    try std.testing.expectEqualStrings("world", doc.getString("c").?);
}

test "find string" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "hello world");
    try doc.setString("other", "hello there");
    try doc.setString("different", "goodbye");

    const results = try doc.findString("hello");
    defer {
        for (results) |r| allocator.free(r);
        allocator.free(results);
    }

    try std.testing.expectEqual(@as(usize, 2), results.len);
}

test "pretty print" {
    const allocator = std.testing.allocator;

    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");

    const output2 = try doc.toPrettyString(2);
    defer allocator.free(output2);
    try std.testing.expect(std.mem.indexOf(u8, output2, "  .name") != null);

    const output4 = try doc.toPrettyString(4);
    defer allocator.free(output4);
    try std.testing.expect(std.mem.indexOf(u8, output4, "    .name") != null);
}

test "file utilities: write/read atomic" {
    const allocator = std.testing.allocator;
    const path = "test_write_atomic.zon";

    _ = std.fs.cwd().deleteFile(path) catch null;

    const data = " .{ .name = \"atomic\" }\n";
    try writeFileAtomic(allocator, path, data);

    const read_back = try readFile(allocator, path);
    defer allocator.free(read_back);

    try std.testing.expect(std.mem.indexOf(u8, read_back, "atomic") != null);

    // cleanup
    _ = std.fs.cwd().deleteFile(path) catch null;
}

test "file utilities: copy & move with overwrite" {
    const allocator = std.testing.allocator;
    _ = std.fs.cwd().deleteFile("a.zon") catch null;
    _ = std.fs.cwd().deleteFile("b.zon") catch null;

    try writeFileAtomic(allocator, "a.zon", ".{ .x = 1 }\n");
    try copyFile("a.zon", "b.zon", true);
    const b_buf = try readFile(allocator, "b.zon");
    defer allocator.free(b_buf);
    try std.testing.expect(std.mem.indexOf(u8, b_buf, "x") != null);

    try moveFile("b.zon", "c.zon", true);
    const c_buf = try readFile(allocator, "c.zon");
    defer allocator.free(c_buf);
    try std.testing.expect(std.mem.indexOf(u8, c_buf, "x") != null);

    // cleanup
    _ = std.fs.cwd().deleteFile("a.zon") catch null;
    _ = std.fs.cwd().deleteFile("c.zon") catch null;
}

test "advanced: special floats" {
    const allocator = std.testing.allocator;
    const source = ".{ .inf_val = inf, .nan_val = nan, .neg_inf = -inf }";
    var doc = try parse(allocator, source);
    defer doc.deinit();

    try std.testing.expect(doc.isInf("inf_val"));
    try std.testing.expect(doc.isNan("nan_val"));
    try std.testing.expect(doc.isInf("neg_inf"));

    const out = try doc.toString();
    defer allocator.free(out);
    try std.testing.expect(std.mem.indexOf(u8, out, ".inf_val = inf") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, ".nan_val = nan") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, ".neg_inf = -inf") != null);
}

test "advanced: multiline strings" {
    const allocator = std.testing.allocator;
    const source = ".{ .text = \\\\line 1\n\\\\line 2\n }";
    var doc = try parse(allocator, source);
    defer doc.deinit();

    const expected = "line 1\nline 2";
    try std.testing.expectEqualStrings(expected, doc.getString("text").?);
}

test "advanced: recursive merge" {
    const allocator = std.testing.allocator;
    var base = try parse(allocator, ".{ .db = .{ .host = \"localhost\", .port = 5432 }, .mode = \"dev\" }");
    defer base.deinit();

    const override = try parse(allocator, ".{ .db = .{ .port = 6000 }, .mode = \"prod\" }");
    var override_mut = override;
    defer override_mut.deinit();

    try base.mergeRecursive(&override_mut);

    try std.testing.expectEqualStrings("localhost", base.getString("db.host").?);
    try std.testing.expectEqual(@as(i64, 6000), base.getInt("db.port").?);
    try std.testing.expectEqualStrings("prod", base.getString("mode").?);
}

test "advanced: deep equality" {
    const allocator = std.testing.allocator;
    var doc1 = try parse(allocator, ".{ .a = 1, .b = .{ .c = 2 } }");
    defer doc1.deinit();
    var doc2 = try parse(allocator, ".{ .b = .{ .c = 2 }, .a = 1 }"); // order doesn't matter for eql
    defer doc2.deinit();
    var doc3 = try parse(allocator, ".{ .a = 1, .b = .{ .c = 3 } }");
    defer doc3.deinit();

    try std.testing.expect(doc1.eql(&doc2));
    try std.testing.expect(!doc1.eql(&doc3));
}

test "advanced: coercion and uint" {
    const allocator = std.testing.allocator;
    var doc = try parse(allocator, ".{ .big = 0xee480fa30d50cbf6, .yes = true, .no = 0, .empty = \"\" }");
    defer doc.deinit();

    try std.testing.expectEqual(@as(u64, 0xee480fa30d50cbf6), doc.getUint("big").?);
    try std.testing.expect(doc.toBool("yes"));
    try std.testing.expect(!doc.toBool("no"));
    try std.testing.expect(!doc.toBool("empty"));
}

test "advanced: type names" {
    const allocator = std.testing.allocator;
    var doc = try parse(allocator, ".{ .s = \"hi\", .i = 1, .b = true, .o = .{}, .a = .{1} }");
    defer doc.deinit();

    try std.testing.expectEqualStrings("string", doc.getTypeName("s").?);
    try std.testing.expectEqualStrings("int", doc.getTypeName("i").?);
    try std.testing.expectEqualStrings("bool", doc.getTypeName("b").?);
    try std.testing.expectEqualStrings("object", doc.getTypeName("o").?);
    try std.testing.expectEqualStrings("array", doc.getTypeName("a").?);
}
