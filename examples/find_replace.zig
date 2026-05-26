const std = @import("std");
const zon = @import("zon");

/// Example: Find and replace operations
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Find and Replace Example ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("server.host", "localhost");
    try doc.setString("server.backup_host", "localhost");
    try doc.setString("database.host", "localhost");
    try doc.setString("cache.host", "192.168.1.100");
    try doc.setInt("server.port", 8080);

    std.debug.print("Initial document:\n", .{});
    const initial = try doc.toString();
    defer allocator.free(initial);
    std.debug.print("{s}\n\n", .{initial});

    std.debug.print("=== Finding 'localhost' ===\n", .{});
    const found = try doc.findString("localhost");
    defer {
        for (found) |f| allocator.free(f);
        allocator.free(found);
    }

    std.debug.print("Found {d} occurrences:\n", .{found.len});
    for (found) |path| {
        std.debug.print("  - {s}\n", .{path});
    }

    std.debug.print("\n=== Replace first 'localhost' with '127.0.0.1' ===\n", .{});
    const replaced_first = try doc.replaceFirst("localhost", "127.0.0.1");
    std.debug.print("Replaced: {}\n", .{replaced_first});

    std.debug.print("\n=== Replace all remaining 'localhost' with 'production.example.com' ===\n", .{});
    const replaced_count = try doc.replaceAll("localhost", "production.example.com");
    std.debug.print("Replaced {d} occurrences\n", .{replaced_count});

    std.debug.print("\n=== Final document ===\n", .{});
    const final = try doc.toString();
    defer allocator.free(final);
    std.debug.print("{s}\n", .{final});
}
