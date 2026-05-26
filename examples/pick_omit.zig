const std = @import("std");
const zon = @import("zon");

/// Example: Using pick() and omit() to create subsets of a ZON document
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Pick Example ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setBool("private", true);
    try doc.setString("config.host", "localhost");
    try doc.setInt("config.port", 8080);

    std.debug.print("Original document:\n", .{});
    const original_str = try doc.toString();
    defer allocator.free(original_str);
    std.debug.print("{s}\n\n", .{original_str});

    // Pick only "name" and "version"
    var picked = try doc.pick(&.{ "name", "version" });
    defer picked.deinit();

    std.debug.print("Picked (name, version):\n", .{});
    const picked_str = try picked.toPrettyString(2);
    defer allocator.free(picked_str);
    std.debug.print("{s}\n\n", .{picked_str});

    // Pick nested path "config.host"
    var picked_nested = try doc.pick(&.{"config.host"});
    defer picked_nested.deinit();

    std.debug.print("Picked (config.host):\n", .{});
    const picked_nested_str = try picked_nested.toPrettyString(2);
    defer allocator.free(picked_nested_str);
    std.debug.print("{s}\n\n", .{picked_nested_str});

    std.debug.print("=== Omit Example ===\n\n", .{});

    // Omit "private" from the document
    var omitted = try doc.omit(&.{"private"});
    defer omitted.deinit();

    std.debug.print("Omitting 'private':\n", .{});
    const omitted_str = try omitted.toPrettyString(2);
    defer allocator.free(omitted_str);
    std.debug.print("{s}\n\n", .{omitted_str});

    // Omit the entire "config" subtree
    var omitted_config = try doc.omit(&.{"config"});
    defer omitted_config.deinit();

    std.debug.print("Omitting 'config':\n", .{});
    const omitted_config_str = try omitted_config.toPrettyString(2);
    defer allocator.free(omitted_config_str);
    std.debug.print("{s}\n", .{omitted_config_str});
}
