const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Creating new ZON document ===\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setBool("private", true);
    try doc.setInt("port", 8080);
    try doc.setFloat("timeout", 30.5);

    try doc.setString("dependencies.http.path", "../http");
    try doc.setString("dependencies.http.version", "0.1.0");
    try doc.setString("dependencies.json.path", "../json");

    std.debug.print("name: {s}\n", .{doc.getString("name").?});
    std.debug.print("version: {s}\n", .{doc.getString("version").?});
    std.debug.print("private: {}\n", .{doc.getBool("private").?});
    std.debug.print("port: {d}\n", .{doc.getInt("port").?});
    std.debug.print("timeout: {d}\n", .{doc.getFloat("timeout").?});
    std.debug.print("http path: {s}\n", .{doc.getString("dependencies.http.path").?});

    std.debug.print("\n=== Advanced Features ===\n", .{});

    std.debug.print("'port' exists: {}\n", .{doc.exists("port")});
    std.debug.print("'missing' exists: {}\n", .{doc.exists("missing")});
    std.debug.print("type of 'name': {s}\n", .{doc.getType("name").?});
    std.debug.print("type of 'port': {s}\n", .{doc.getType("port").?});
    std.debug.print("root key count: {d}\n", .{doc.count()});

    std.debug.print("\n=== Updating values ===\n", .{});

    try doc.setString("version", "2.0.0");
    std.debug.print("new version: {s}\n", .{doc.getString("version").?});

    std.debug.print("\n=== Deleting values ===\n", .{});

    const deleted = doc.delete("private");
    std.debug.print("deleted 'private': {}\n", .{deleted});
    std.debug.print("private now: {?}\n", .{doc.getBool("private")});

    std.debug.print("\n=== Generated ZON ===\n", .{});

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});

    std.debug.print("\n=== File Operations ===\n", .{});

    try doc.saveAs("output.zon");
    std.debug.print("Saved to output.zon\n", .{});
    std.debug.print("output.zon exists: {}\n", .{zon.fileExists("output.zon")});

    std.debug.print("\n=== Library Version ===\n", .{});
    std.debug.print("zon.zig version: {s}\n", .{zon.version});
}
