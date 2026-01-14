const std = @import("std");
const zon = @import("zon");

/// Example: Array operations
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Array Operations Example ===\n\n", .{});

    const source =
        \\.{
        \\    .paths = .{
        \\        "src",
        \\        "lib",
        \\    },
        \\    .tags = .{
        \\        "stable",
        \\        "production",
        \\    },
        \\}
    ;

    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    std.debug.print("=== Reading arrays ===\n", .{});

    const paths_len = doc.arrayLen("paths").?;
    std.debug.print("paths has {d} elements:\n", .{paths_len});

    var i: usize = 0;
    while (doc.getArrayString("paths", i)) |path| : (i += 1) {
        std.debug.print("  [{d}] = {s}\n", .{ i, path });
    }

    std.debug.print("\ntags:\n", .{});
    i = 0;
    while (doc.getArrayString("tags", i)) |tag| : (i += 1) {
        std.debug.print("  [{d}] = {s}\n", .{ i, tag });
    }

    std.debug.print("\n=== Appending to arrays ===\n", .{});

    try doc.appendToArray("paths", "tests");
    try doc.appendToArray("paths", "docs");
    try doc.appendToArray("tags", "latest");

    std.debug.print("After appending:\n", .{});
    std.debug.print("paths now has {d} elements\n", .{doc.arrayLen("paths").?});
    std.debug.print("tags now has {d} elements\n", .{doc.arrayLen("tags").?});

    std.debug.print("\n=== Creating new array ===\n", .{});

    try doc.setArray("numbers");
    try doc.appendIntToArray("numbers", 1);
    try doc.appendIntToArray("numbers", 2);
    try doc.appendIntToArray("numbers", 3);

    std.debug.print("Created numbers array with {d} elements\n", .{doc.arrayLen("numbers").?});

    std.debug.print("\n=== Pop, Shift, Unshift ===\n", .{});

    // Pop (remove from end)
    _ = doc.popFromArray("numbers"); // Removes 3
    std.debug.print("Popped from numbers (len: {d})\n", .{doc.arrayLen("numbers").?});

    // Shift (remove from start)
    _ = doc.shiftArray("numbers"); // Removes 1
    std.debug.print("Shifted from numbers (len: {d})\n", .{doc.arrayLen("numbers").?});

    // Unshift (add to start)
    try doc.unshiftArray("numbers", .{ .number = .{ .int = 0 } });
    std.debug.print("Unshifted 0 to numbers (len: {d})\n", .{doc.arrayLen("numbers").?});
    std.debug.print("New first element: {d}\n", .{doc.getArrayInt("numbers", 0).?});

    std.debug.print("\n=== Final document ===\n", .{});

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});
}
