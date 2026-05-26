const std = @import("std");
const zon = @import("zon");

/// Example: sortKeys() and sort_keys stringify option
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== sort_keys Stringify Example ===\n\n", .{});

    // Parse a ZON document with unsorted keys
    const source =
        \\.{
        \\    .z = "last",
        \\    .m = 42,
        \\    .a = "first",
        \\    .nested = .{
        \\      .y = "inner last",
        \\      .b = "inner first",
        \\    },
        \\}
    ;

    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    // Stringify with sort_keys=false preserves insertion order
    const unsorted = try zon.stringify(allocator, &doc.root, .{ .sort_keys = false });
    defer allocator.free(unsorted);
    std.debug.print("Unsorted (insertion order, sort_keys=false):\n{s}\n\n", .{unsorted});

    // Stringify with sort_keys=true (default) sorts alphabetically
    const sorted_str = try zon.stringify(allocator, &doc.root, .{ .sort_keys = true });
    defer allocator.free(sorted_str);
    std.debug.print("Sorted (alphabetical, sort_keys=true):\n{s}\n\n", .{sorted_str});

    std.debug.print("=== sortKeys() In-Place Sort ===\n\n", .{});

    // Build an unsorted document programmatically
    var doc2 = zon.create(allocator);
    defer doc2.deinit();

    var obj = zon.Value.Object.init(allocator);
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("m", .{ .string = try allocator.dupe(u8, "middle") });

    var inner_obj = zon.Value.Object.init(allocator);
    try inner_obj.put("y", .{ .string = try allocator.dupe(u8, "inner_last") });
    try inner_obj.put("b", .{ .string = try allocator.dupe(u8, "inner_first") });
    try obj.put("nested", .{ .object = inner_obj });

    doc2.root = .{ .object = obj };

    std.debug.print("Before sortKeys():\n", .{});
    const before = try doc2.toPrettyString(2);
    defer allocator.free(before);
    std.debug.print("{s}\n\n", .{before});

    doc2.sortKeys();

    std.debug.print("After sortKeys():\n", .{});
    const after = try doc2.toPrettyString(2);
    defer allocator.free(after);
    std.debug.print("{s}\n", .{after});
}
