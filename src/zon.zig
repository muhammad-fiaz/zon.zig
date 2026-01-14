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
pub const utils = @import("utils.zig");

pub const Document = document.Document;
pub const Parser = @import("parser.zig").Parser;
pub const ParseError = @import("parser.zig").ParseError;
pub const Diagnostic = @import("parser.zig").Diagnostic;
pub const Tokenizer = @import("tokenizer.zig").Tokenizer;
pub const Token = @import("tokenizer.zig").Token;
pub const version = version_info.version;
pub const stringify = @import("stringify.zig").stringify;
pub const stringifyJson = @import("stringify.zig").stringifyJson;

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

/// Creates a new empty ZON document.
pub fn create(allocator: Allocator) Document {
    return Document.initEmpty(allocator);
}

/// Alias for create().
pub fn new(allocator: Allocator) Document {
    return create(allocator);
}

/// Alias for create().
pub fn init(allocator: Allocator) Document {
    return create(allocator);
}

/// Parses ZON content from source text.
pub fn parse(allocator: Allocator, source: []const u8) !Document {
    return Document.initFromSource(allocator, source);
}

/// Alias for parse().
pub fn fromSource(allocator: Allocator, source: []const u8) !Document {
    return parse(allocator, source);
}

/// Alias for parse().
pub fn parseString(allocator: Allocator, source: []const u8) !Document {
    return parse(allocator, source);
}

/// Parses JSON content into a ZON document.
pub fn fromJson(allocator: Allocator, json: []const u8) !Document {
    return Document.initFromJson(allocator, json);
}

/// Alias for fromJson().
pub fn parseJson(allocator: Allocator, json: []const u8) !Document {
    return fromJson(allocator, json);
}

/// Creates a ZON document from a map of key-value pairs.
pub fn fromMap(allocator: Allocator, map: anytype) !Document {
    return Document.initFromMap(allocator, map);
}

/// Alias for fromMap().
pub fn initFromMap(allocator: Allocator, map: anytype) !Document {
    return fromMap(allocator, map);
}

/// Creates a Document from a Zig struct or value.
pub fn fromStruct(allocator: Allocator, value: anytype) !Document {
    return Document.initFromStruct(allocator, value);
}

/// Alias for fromStruct.
pub fn initFromStruct(allocator: Allocator, value: anytype) !Document {
    return fromStruct(allocator, value);
}

/// Opens and parses a ZON file.
pub fn load(allocator: Allocator, path: []const u8) !Document {
    return Document.initFromFile(allocator, path);
}

/// Alias for load().
pub fn fromFile(allocator: Allocator, path: []const u8) !Document {
    return load(allocator, path);
}

/// Alias for load().
pub fn openFile(allocator: Allocator, path: []const u8) !Document {
    return load(allocator, path);
}

/// Opens an existing ZON file.
pub fn open(allocator: Allocator, file_path: []const u8) !Document {
    return Document.initFromFile(allocator, file_path);
}

/// Alias for open().
pub fn loadFile(allocator: Allocator, file_path: []const u8) !Document {
    return open(allocator, file_path);
}

/// Alias for load().
pub fn parseFile(allocator: Allocator, path: []const u8) !Document {
    return load(allocator, path);
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

/// Alias for readFile().
pub fn read(allocator: Allocator, path: []const u8) ![]u8 {
    return readFile(allocator, path);
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

/// Alias for writeFileAtomic().
pub fn writeAtomic(allocator: Allocator, path: []const u8, data: []const u8) !void {
    try writeFileAtomic(allocator, path, data);
}

/// Alias for writeFileAtomic().
pub fn saveAtomic(allocator: Allocator, path: []const u8, data: []const u8) !void {
    try writeFileAtomic(allocator, path, data);
}

/// Loads a ZON file, or creates it with default_content if it doesn't exist.
pub fn loadOrCreate(allocator: Allocator, path: []const u8, default_content: []const u8) !Document {
    if (!fileExists(path)) {
        try writeFileAtomic(allocator, path, default_content);
    }
    return try load(allocator, path);
}

/// Returns true if the source is valid ZON.
pub fn validate(allocator: Allocator, source: []const u8) bool {
    var doc = Document.initFromSource(allocator, source) catch return false;
    doc.deinit();
    return true;
}

/// Alias for validate().
pub fn isValid(allocator: Allocator, source: []const u8) bool {
    return validate(allocator, source);
}

/// Alias for validate().
pub fn isZonValid(allocator: Allocator, source: []const u8) bool {
    return validate(allocator, source);
}

/// Returns true if the file contains valid ZON.
pub fn validateFile(allocator: Allocator, path: []const u8) bool {
    const source = readFile(allocator, path) catch return false;
    defer allocator.free(source);
    return validate(allocator, source);
}

/// Alias for validateFile().
pub fn isValidFile(allocator: Allocator, path: []const u8) bool {
    return validateFile(allocator, path);
}

/// Alias for validateFile().
pub fn isZonFileValid(allocator: Allocator, path: []const u8) bool {
    return validateFile(allocator, path);
}

/// Re-formats ZON source code.
pub fn format(allocator: Allocator, source: []const u8) ![]u8 {
    var doc = try Document.initFromSource(allocator, source);
    defer doc.deinit();
    return try doc.toString();
}

/// Re-formats a ZON file in-place.
pub fn formatFile(allocator: Allocator, path: []const u8) !void {
    const source = try readFile(allocator, path);
    defer allocator.free(source);
    const formatted = try format(allocator, source);
    defer allocator.free(formatted);
    try writeFileAtomic(allocator, path, formatted);
}

/// Rename a key path in a ZON file.
pub fn movePathInFile(allocator: Allocator, path: []const u8, old_key: []const u8, new_key: []const u8) !void {
    var doc = try load(allocator, path);
    defer doc.deinit();
    if (try doc.rename(old_key, new_key)) {
        try doc.save();
    }
}

/// Copy a key path in a ZON file.
pub fn copyPathInFile(allocator: Allocator, path: []const u8, src_key: []const u8, dst_key: []const u8) !void {
    var doc = try load(allocator, path);
    defer doc.deinit();
    if (try doc.copy(src_key, dst_key)) {
        try doc.save();
    }
}

/// Alias for moveFile().
pub fn renameFile(old_path: []const u8, new_path: []const u8, overwrite: bool) !void {
    try moveFile(old_path, new_path, overwrite);
}

/// Alias for deleteFile().
pub fn removeFile(path: []const u8) !void {
    try deleteFile(path);
}

/// Alias for fileExists().
pub fn hasFile(path: []const u8) bool {
    return fileExists(path);
}

/// Converts a Document to a Zig struct.
pub fn toStruct(doc: *const Document, comptime T: type) !T {
    return doc.toStruct(T);
}

/// Alias for toStruct (deserialization).
pub fn unmarshal(doc: *const Document, comptime T: type) !T {
    return doc.toStruct(T);
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
    try std.testing.expectEqualStrings("0.0.4", version);
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
    try std.testing.expectEqualStrings("object", doc.getTypeName("o").?);
    try std.testing.expectEqualStrings("array", doc.getTypeName("a").?);
}

test "advanced: JSON export" {
    const allocator = std.testing.allocator;
    const source = ".{ .name = \"test\", .enabled = true, .count = 42, .tags = .{ \"a\", \"b\" } }";
    var doc = try parse(allocator, source);
    defer doc.deinit();

    const json = try doc.toJsonString();
    defer allocator.free(json);

    // Basic JSON checks - note order may vary due to HashMap
    try std.testing.expect(std.mem.indexOf(u8, json, "\"name\":\"test\"") != null or std.mem.indexOf(u8, json, "\"name\": \"test\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"enabled\":true") != null or std.mem.indexOf(u8, json, "\"enabled\": true") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"tags\":[\"a\", \"b\"]") != null or std.mem.indexOf(u8, json, "\"tags\": [\"a\", \"b\"]") != null);
}

test "advanced: iterators" {
    const allocator = std.testing.allocator;
    const source = ".{ .items = .{ 1, 2, 3 }, .meta = .{ .id = 100 } }";
    var doc = try parse(allocator, source);
    defer doc.deinit();

    const items = doc.root.asObject().?.get("items").?.asArray().?;
    var it = items.iterator();
    var sum: i64 = 0;
    while (it.next()) |val| {
        sum += val.asInt().?;
    }
    try std.testing.expectEqual(@as(i64, 6), sum);

    const meta = doc.root.asObject().?.get("meta").?.asObject().?;
    var obj_it = meta.iterator();
    if (obj_it.next()) |entry| {
        try std.testing.expectEqualStrings("id", entry.key);
        try std.testing.expectEqual(@as(i64, 100), entry.value.asInt().?);
    }
}

test "advanced: recursive find" {
    const allocator = std.testing.allocator;
    const source = ".{ .outer = .{ .inner = .{ .target = \"found me\" } } }";
    var doc = try parse(allocator, source);
    defer doc.deinit();

    const result = doc.find("target");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("found me", result.?.asString().?);

    try std.testing.expect(doc.find("missing") == null);
}

test "advanced: numeric coercion" {
    const allocator = std.testing.allocator;
    var doc = try Document.initFromSource(allocator, ".{ .val = 123 }");
    defer doc.deinit();

    try std.testing.expectEqual(@as(u32, 123), doc.toUint("val", u32));
    try std.testing.expectEqual(@as(i16, 123), doc.toInt("val", i16));
    try std.testing.expectApproxEqAbs(@as(f32, 123.0), doc.toFloat("val", f32), 0.001);
}

test "advanced: hash and size" {
    const allocator = std.testing.allocator;
    const s1 = ".{ .a = 1, .b = 2 }";
    const s2 = ".{ .b = 2, .a = 1 }"; // Different order

    var doc1 = try Document.initFromSource(allocator, s1);
    defer doc1.deinit();
    var doc2 = try Document.initFromSource(allocator, s2);
    defer doc2.deinit();

    // Stability: same content should have same hash regardless of order
    try std.testing.expectEqual(doc1.hash(), doc2.hash());

    // Size checks
    try std.testing.expect(try doc1.byteSize() > 0);
    try std.testing.expect(try doc1.compactSize() > 0);
}

test "advanced: checksum" {
    const allocator = std.testing.allocator;
    var doc = try Document.initFromSource(allocator, ".{ .name = \"checksum_test\" }");
    defer doc.deinit();

    var sha256_1: [32]u8 = undefined;
    doc.checksum(std.crypto.hash.sha2.Sha256, &sha256_1);

    var sha256_2: [32]u8 = undefined;
    doc.checksum(std.crypto.hash.sha2.Sha256, &sha256_2);

    // Consistency check
    try std.testing.expectEqualStrings(&sha256_1, &sha256_2);
}

test "advanced: json import" {
    const allocator = std.testing.allocator;
    const json = "{\"a\": 1, \"b\": [true, null], \"c\": \"hello\"}";
    var doc = try Document.initFromJson(allocator, json);
    defer doc.deinit();

    try std.testing.expectEqual(@as(i64, 1), doc.getInt("a").?);
    try std.testing.expectEqual(true, doc.getArrayBool("b", 0).?);
    try std.testing.expect(doc.getArrayElement("b", 1).?.isNull());
    try std.testing.expectEqualStrings("hello", doc.getString("c").?);
}

test "advanced: flatten" {
    const allocator = std.testing.allocator;
    const source = ".{ .db = .{ .host = \"localhost\", .ports = .{ 80, 443 } } }";
    var doc = try Document.initFromSource(allocator, source);
    defer doc.deinit();

    var flat = try doc.flatten();
    defer flat.deinit();

    try std.testing.expectEqualStrings("localhost", flat.getString("db.host").?);
    try std.testing.expectEqual(@as(i64, 80), flat.getInt("db.ports[0]").?);
    try std.testing.expectEqual(@as(i64, 443), flat.getInt("db.ports[1]").?);
}

test "advanced: raw identifiers and findAll" {
    const allocator = std.testing.allocator;
    const source = ".{ .@\"special-key\" = 1, .nested = .{ .@\"special-key\" = 2 } }";
    var doc = try Document.initFromSource(allocator, source);
    defer doc.deinit();

    try std.testing.expectEqual(@as(i64, 1), doc.getInt("special-key").?);
    try std.testing.expectEqual(@as(i64, 2), doc.getInt("nested.special-key").?);

    const paths = try doc.findAll("special-key");
    defer {
        for (paths) |p| allocator.free(p);
        allocator.free(paths);
    }

    try std.testing.expectEqual(@as(usize, 2), paths.len);
}

test "advanced: rename and copy" {
    const allocator = std.testing.allocator;
    var doc = try parse(allocator, ".{ .a = 1 }");
    defer doc.deinit();

    try std.testing.expect(try doc.rename("a", "b"));
    try std.testing.expect(!doc.exists("a"));
    try std.testing.expectEqual(@as(i64, 1), doc.getInt("b").?);

    try std.testing.expect(try doc.copy("b", "c"));
    try std.testing.expectEqual(@as(i64, 1), doc.getInt("b").?);
    try std.testing.expectEqual(@as(i64, 1), doc.getInt("c").?);
}

test "advanced: character literals" {
    const allocator = std.testing.allocator;
    const source = ".{ .char = 'A', .newline = '\\n' }";
    var doc = try Document.initFromSource(allocator, source);
    defer doc.deinit();

    try std.testing.expectEqual(@as(i64, 65), doc.getInt("char").?);
    try std.testing.expectEqual(@as(i64, 10), doc.getInt("newline").?);
}

test "advanced: getOr variants" {
    const allocator = std.testing.allocator;
    var doc = Document.initEmpty(allocator);
    defer doc.deinit();

    try std.testing.expectEqualStrings("default", doc.getStringOr("missing", "default"));
    try std.testing.expectEqual(@as(i64, 42), doc.getIntOr("missing", 42));
    try std.testing.expectEqual(true, doc.getBoolOr("missing", true));

    try doc.setInt("exists", 100);
    try std.testing.expectEqual(@as(i64, 100), doc.getIntOr("exists", 0));
}

test "advanced: initFromMap" {
    const allocator = std.testing.allocator;
    var doc = try Document.initFromMap(allocator, .{
        .name = "zon",
        .version = @as(i32, 3),
        .active = true,
    });
    defer doc.deinit();

    try std.testing.expectEqualStrings("zon", doc.getString("name").?);
    try std.testing.expectEqual(@as(i64, 3), doc.getInt("version").?);
    try std.testing.expectEqual(true, doc.getBool("active").?);
}

test "runtime struct conversion: fromStruct" {
    const allocator = std.testing.allocator;
    const Config = struct {
        name: []const u8,
        port: u16,
        tags: []const []const u8,
    };

    const config = Config{
        .name = "server",
        .port = 8080,
        .tags = &.{ "prod", "api" },
    };

    var doc = try fromStruct(allocator, config);
    defer doc.deinit();

    try std.testing.expectEqualStrings("server", doc.getString("name").?);
    try std.testing.expectEqual(@as(i64, 8080), doc.getInt("port").?);
    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("tags").?);
    try std.testing.expectEqualStrings("prod", doc.getArrayString("tags", 0).?);

    // Round trip
    const parsed = try doc.toStruct(Config);
    defer {
        allocator.free(parsed.name);
        for (parsed.tags) |t| allocator.free(t);
        allocator.free(parsed.tags);
    }
    try std.testing.expectEqualStrings("server", parsed.name);
}

test "array extensions: pop, shift, unshift" {
    const allocator = std.testing.allocator;
    var doc = create(allocator);
    defer doc.deinit();

    try doc.setArray("list");
    try doc.appendToArray("list", "b");
    try doc.appendToArray("list", "c");

    // Unshift "a" -> ["a", "b", "c"]
    try doc.unshiftArray("list", .{ .string = try allocator.dupe(u8, "a") });
    try std.testing.expectEqualStrings("a", doc.getArrayString("list", 0).?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("list", 1).?);

    // Pop "c" -> ["a", "b"]
    var popped = doc.popFromArray("list").?;
    defer popped.deinit(allocator);
    try std.testing.expectEqualStrings("c", popped.asString().?);
    try std.testing.expectEqual(@as(usize, 2), doc.arrayLen("list").?);

    // Shift "a" -> ["b"]
    var shifted = doc.shiftArray("list").?;
    defer shifted.deinit(allocator);
    try std.testing.expectEqualStrings("a", shifted.asString().?);
    try std.testing.expectEqual(@as(usize, 1), doc.arrayLen("list").?);
    try std.testing.expectEqualStrings("b", doc.getArrayString("list", 0).?);
}

test "document file management" {
    const allocator = std.testing.allocator;
    const path = "test_doc_file.zon";
    _ = std.fs.cwd().deleteFile(path) catch {};
    defer _ = std.fs.cwd().deleteFile(path) catch {};

    var doc = create(allocator);
    // Verify modification time tracking and external change detection.
    try doc.saveAsAtomic(path);

    // Re-initialize document from file to establish file path association and timestamps.
    doc.deinit();
    doc = try load(allocator, path);
    defer doc.deinit();

    // Verify no external changes detected initially.
    try std.testing.expect(!doc.hasChangedOnDisk());

    // Simulate external modification.
    // Ensure sufficient delay for filesystem modification time resolution.
    std.Thread.sleep(20 * std.time.ns_per_ms);

    try writeFileAtomic(allocator, path, ".{ .status = \"changed\" }");
    try std.testing.expect(doc.hasChangedOnDisk());

    // Verify reload invalidates current state and reads from disk.
    try doc.reload();
    try std.testing.expectEqualStrings("changed", doc.getString("status").?);

    // Verify renaming the backing file and updating internal path state.
    const new_path = "test_doc_renamed.zon";
    _ = std.fs.cwd().deleteFile(new_path) catch {};
    defer _ = std.fs.cwd().deleteFile(new_path) catch {};

    try doc.renameFileOnDisk(new_path);
    try std.testing.expectEqualStrings(new_path, doc.file_path.?);
    try std.testing.expect(fileExists(new_path));
    try std.testing.expect(!fileExists(path));

    // Test deleteFileOnDisk
    try doc.deleteFileOnDisk();
    try std.testing.expect(!fileExists(new_path));
}

test "advanced: file path utilities" {
    const allocator = std.testing.allocator;
    const path = "test_path_utils.zon";
    defer _ = std.fs.cwd().deleteFile(path) catch null;

    try writeFileAtomic(allocator, path, ".{ .old = 123 }");

    try movePathInFile(allocator, path, "old", "new");
    var doc1 = try load(allocator, path);
    defer doc1.deinit();
    try std.testing.expect(!doc1.exists("old"));
    try std.testing.expectEqual(@as(i64, 123), doc1.getInt("new").?);

    try copyPathInFile(allocator, path, "new", "dupe");
    var doc2 = try load(allocator, path);
    defer doc2.deinit();
    try std.testing.expectEqual(@as(i64, 123), doc2.getInt("new").?);
    try std.testing.expectEqual(@as(i64, 123), doc2.getInt("dupe").?);
}

test "struct conversion from top-level" {
    const allocator = std.testing.allocator;
    var doc = create(allocator);
    defer doc.deinit();

    try doc.setString("name", "my-lib");
    try doc.setInt("version", 1);
    try doc.setBool("public", true);

    const Config = struct {
        name: []const u8,
        version: i32,
        public: bool,
    };

    const config = try toStruct(&doc, Config);
    defer allocator.free(config.name);

    try std.testing.expectEqualStrings("my-lib", config.name);
    try std.testing.expectEqual(@as(i32, 1), config.version);
    try std.testing.expect(config.public);
}
