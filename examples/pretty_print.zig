const std = @import("std");
const zon = @import("zon");

/// Example: Pretty printing with different indentation
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Pretty Print Example ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setString("config.server.host", "localhost");
    try doc.setInt("config.server.port", 8080);
    try doc.setBool("config.server.ssl", true);
    try doc.setString("config.database.url", "postgres://localhost/mydb");

    std.debug.print("=== Compact (no indentation) ===\n", .{});
    const compact = try doc.toCompactString();
    defer allocator.free(compact);
    std.debug.print("{s}\n\n", .{compact});

    std.debug.print("=== 2-space indentation ===\n", .{});
    const twoSpace = try doc.toPrettyString(2);
    defer allocator.free(twoSpace);
    std.debug.print("{s}\n\n", .{twoSpace});

    std.debug.print("=== 4-space indentation (default) ===\n", .{});
    const fourSpace = try doc.toString();
    defer allocator.free(fourSpace);
    std.debug.print("{s}\n\n", .{fourSpace});

    std.debug.print("=== 8-space indentation ===\n", .{});
    const eightSpace = try doc.toPrettyString(8);
    defer allocator.free(eightSpace);
    std.debug.print("{s}\n", .{eightSpace});
}
