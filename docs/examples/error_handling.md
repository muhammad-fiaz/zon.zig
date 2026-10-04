---
title: "Error Handling Example"
description: "Handle parse errors, file errors, and missing values with defaults."
---

# Error Handling Example

**Usecase:** parse safely — valid input succeeds, malformed input surfaces
`error.UnexpectedToken` instead of crashing, and missing values fall back
to defaults with `orelse`.

**Run:** `zig build run-error_handling`

```zig
const std = @import("std");
const zon = @import("zon");

/// Example: Error handling when parsing ZON
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Error Handling Example ===\n\n", .{});

    // Example 1: Valid ZON parsing
    std.debug.print("1. Parsing valid ZON:\n", .{});
    {
        const validSource =
            \\.{
            \\    .name = "myapp",
            \\    .version = "1.0.0",
            \\}
        ;

        var doc = zon.parse(allocator, validSource) catch |err| {
            std.debug.print("   Error: {}\n", .{err});
            return;
        };
        defer doc.deinit();
        std.debug.print("   Success! name = {s}\n", .{doc.getString("name").?});
    }

    // Example 2: Invalid ZON syntax
    std.debug.print("\n2. Parsing invalid ZON (missing closing brace):\n", .{});
    {
        const invalidSource =
            \\.{
            \\    .name = "myapp"
        ;

        var doc = zon.parse(allocator, invalidSource) catch |err| {
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
```

Actual output:

```bash
=== Error Handling Example ===

1. Parsing valid ZON:
   Success! name = myapp

2. Parsing invalid ZON (missing closing brace):
   Expected error: error.UnexpectedToken
```
