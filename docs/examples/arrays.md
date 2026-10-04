---
title: "Arrays Example"
description: "Create arrays, append, insert, read, pop, shift, and unshift elements."
---

# Arrays Example

**Usecase:** everything array-shaped — create arrays, append strings and
integers, read by index, insert at positions, and reshape with pop, shift,
and unshift while tracking lengths.

**Run:** `zig build run-arrays`

```zig
const std = @import("std");
const zon = @import("zon");

/// Example: Array operations
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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

    const pathsLen = doc.arrayLen("paths").?;
    std.debug.print("paths has {d} elements:\n", .{pathsLen});

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
```

```bash
=== Array Operations Example ===

=== Reading arrays ===
paths has 2 elements:
  [0] = src
  [1] = lib

tags:
  [0] = stable
  [1] = production

=== Appending to arrays ===
After appending:
paths now has 4 elements
tags now has 3 elements

=== Creating new array ===
Created numbers array with 3 elements

=== Pop, Shift, Unshift ===
Popped from numbers (len: 2)
Shifted from numbers (len: 1)
Unshifted 0 to numbers (len: 2)
New first element: 0

=== Final document ===
.{
    .numbers = .{
        0,
        2,
    },
    .paths = .{
        "src",
        "lib",
        "tests",
        "docs",
    },
    .tags = .{
        "stable",
        "production",
        "latest",
    },
}
```
