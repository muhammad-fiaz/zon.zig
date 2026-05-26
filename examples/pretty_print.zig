const std = @import("std");
const zon = @import("zon");

/// Example: Pretty printing with different indentation
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

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
    const two_space = try doc.toPrettyString(2);
    defer allocator.free(two_space);
    std.debug.print("{s}\n\n", .{two_space});

    std.debug.print("=== 4-space indentation (default) ===\n", .{});
    const four_space = try doc.toString();
    defer allocator.free(four_space);
    std.debug.print("{s}\n\n", .{four_space});

    std.debug.print("=== 8-space indentation ===\n", .{});
    const eight_space = try doc.toPrettyString(8);
    defer allocator.free(eight_space);
    std.debug.print("{s}\n", .{eight_space});
}
