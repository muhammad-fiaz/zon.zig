const std = @import("std");
const zon = @import("zon");

/// Example: Merging and cloning documents
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Merge and Clone Example ===\n\n", .{});

    var base = zon.create(allocator);
    defer base.deinit();

    try base.setString("name", "myapp");
    try base.setString("version", "1.0.0");
    try base.setInt("port", 8080);
    try base.setString("database.host", "localhost");

    std.debug.print("Base document:\n", .{});
    const base_str = try base.toString();
    defer allocator.free(base_str);
    std.debug.print("{s}\n\n", .{base_str});

    var override = zon.create(allocator);
    defer override.deinit();

    try override.setInt("port", 9000);
    try override.setString("database.host", "production.example.com");
    try override.setString("database.password", "secret123");
    try override.setBool("debug", false);

    std.debug.print("Override document:\n", .{});
    const override_str = try override.toString();
    defer allocator.free(override_str);
    std.debug.print("{s}\n\n", .{override_str});

    std.debug.print("=== Merging override into base ===\n", .{});
    try base.merge(&override);

    const merged_str = try base.toString();
    defer allocator.free(merged_str);
    std.debug.print("{s}\n\n", .{merged_str});

    std.debug.print("=== Cloning document ===\n", .{});
    var cloned = try base.clone();
    defer cloned.deinit();

    try cloned.setString("name", "myapp-clone");
    try cloned.setString("version", "2.0.0");

    std.debug.print("Original after clone modification:\n", .{});
    std.debug.print("  name: {s}\n", .{base.getString("name").?});
    std.debug.print("  version: {s}\n", .{base.getString("version").?});

    std.debug.print("\nCloned document:\n", .{});
    std.debug.print("  name: {s}\n", .{cloned.getString("name").?});
    std.debug.print("  version: {s}\n", .{cloned.getString("version").?});

    std.debug.print("\nClone is independent from original!\n", .{});
}
