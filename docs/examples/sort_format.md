---
title: "Sort and Format Example"
description: "Alphabetical vs insertion-order output and recursive in-place key sorting."
---

# Sort & Format Example

**Usecase:** control key order on output (`sortKeys` option: insertion order
vs alphabetical) and sort in place (`sortKeys`, `sortKeysDesc`); nested
objects are handled recursively in both modes.

**Run:** `zig build run-sort_format`

```zig
const std = @import("std");
const zon = @import("zon");

/// Example: sortKeys() and sortKeys stringify option
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== sortKeys Stringify Example ===\n\n", .{});

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

    // Stringify with sortKeys=false preserves insertion order
    const unsorted = try zon.stringify(allocator, &doc.root, .{ .sortKeys = false });
    defer allocator.free(unsorted);
    std.debug.print("Unsorted (insertion order, sortKeys=false):\n{s}\n\n", .{unsorted});

    // Stringify with sortKeys=true (default) sorts alphabetically
    const sortedStr = try zon.stringify(allocator, &doc.root, .{ .sortKeys = true });
    defer allocator.free(sortedStr);
    std.debug.print("Sorted (alphabetical, sortKeys=true):\n{s}\n\n", .{sortedStr});

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
```

```bash
=== sortKeys Stringify Example ===

Unsorted (insertion order, sortKeys=false):
.{
    .z = "last",
    .a = "first",
    .nested = .{
        .b = "inner first",
        .y = "inner last",
    },
    .m = 42,
}

Sorted (alphabetical, sortKeys=true):
.{
    .a = "first",
    .m = 42,
    .nested = .{
        .b = "inner first",
        .y = "inner last",
    },
    .z = "last",
}

=== sortKeys() In-Place Sort ===

Before sortKeys():
.{
  .a = "first",
  .m = "middle",
  .nested = .{
    .b = "inner_first",
    .y = "inner_last",
  },
  .z = "last",
}

After sortKeys():
.{
  .a = "first",
  .m = "middle",
  .nested = .{
    .b = "inner_first",
    .y = "inner_last",
  },
  .z = "last",
}
```
