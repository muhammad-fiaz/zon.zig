const std = @import("std");
const zon = @import("zon");

/// Example: Error handling when parsing ZON
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Error Handling Example ===\n\n", .{});

    // Example 1: Valid ZON parsing
    std.debug.print("1. Parsing valid ZON:\n", .{});
    {
        const valid_source =
            \\.{
            \\    .name = "myapp",
            \\    .version = "1.0.0",
            \\}
        ;

        var doc = zon.parse(allocator, valid_source) catch |err| {
            std.debug.print("   Error: {}\n", .{err});
            return;
        };
        defer doc.deinit();
        std.debug.print("   Success! name = {s}\n", .{doc.getString("name").?});
    }

    // Example 2: Invalid ZON syntax
    std.debug.print("\n2. Parsing invalid ZON (missing closing brace):\n", .{});
    {
        const invalid_source =
            \\.{
            \\    .name = "myapp"
        ;

        var doc = zon.parse(allocator, invalid_source) catch |err| {
            std.debug.print("   Expected error: {}\n", .{err});
            return;
        };
        doc.deinit();
        std.debug.print("   Unexpectedly succeeded\n", .{});
    }

    // Example 3: File not found
    std.debug.print("\n3. Opening non-existent file:\n", .{});
    {
        var doc = zon.open(allocator, "nonexistent.zon") catch |err| {
            std.debug.print("   Expected error: {}\n", .{err});
            return;
        };
        doc.deinit();
        std.debug.print("   Unexpectedly succeeded\n", .{});
    }
}
