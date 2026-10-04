---
title: "Struct Conversion Example"
description: "Convert Zig structs to ZON documents and ZON documents back to structs."
---

# Struct Conversion Example

**Usecase:** bridge static and dynamic worlds — build a document from a Zig
struct (`zon.fromStruct`), convert it back (`doc.toStruct`) with integer,
float, boolean, string, and slice fields, plus single-value conversion via
`Value.from` / `Value.to`.

**Run:** `zig build run-struct_conversion`

```zig
//! Example: Converting between ZON Documents and Zig Structs
//!
//! This example demonstrates how to:
//! 1. Initialize a ZON document from a Zig struct (`initFromStruct` / `zon.fromStruct`)
//! 2. Convert a ZON document back to a Zig struct (`toStruct`)
//! 3. Use `Value.to(T)` and `Value.from(allocator, T)` for individual values

const std = @import("std");
const zon = @import("zon");

const ServerConfig = struct {
    host: []const u8,
    port: u16,
    ssl: bool = false,
    max_connections: ?u32 = null,
    tags: []const []const u8 = &.{},
};

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();

    // Use an ArenaAllocator for easy cleanup of all allocations (document and structs)
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // ----------------------------------------------------
    // 1. Struct to ZON Document
    // ----------------------------------------------------
    std.debug.print("1. Creating ZON from struct...\n", .{});

    const myConfig = ServerConfig{
        .host = "localhost",
        .port = 8080,
        .ssl = true,
        .tags = &.{ "web", "api", "v1" },
    };

    // Create a generic Document from the specific struct
    var doc = try zon.fromStruct(allocator, myConfig);
    defer doc.deinit();

    // The document is now editable!
    try doc.setString("host", "127.0.0.1"); // Change a value
    try doc.setInt("max_connections", 1000); // Set an optional field (now non-null)

    // Print the ZON representation
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("Generated ZON:\n{s}\n", .{output});

    // ----------------------------------------------------
    // 2. ZON Document to Struct
    // ----------------------------------------------------
    std.debug.print("\n2. Converting ZON back to struct...\n", .{});

    // Convert the (modified) document back to a struct
    // Note: The returned struct owns its memory (strings/arrays are deeply copied using the document's allocator).
    // In a real application, consider using an ArenaAllocator for the document to simplify cleanup,
    // or manually free the allocated fields in the struct.
    const newConfig = try doc.toStruct(ServerConfig);

    std.debug.print("Parsed Config:\n", .{});
    std.debug.print("  Host: {s}\n", .{newConfig.host});
    std.debug.print("  Port: {d}\n", .{newConfig.port});
    std.debug.print("  SSL: {}\n", .{newConfig.ssl});
    std.debug.print("  Max Conn: {?}\n", .{newConfig.max_connections});
    std.debug.print("  Tags:", .{});
    for (newConfig.tags) |tag| std.debug.print(" {s}", .{tag});
    std.debug.print("\n", .{});

    // ----------------------------------------------------
    // 3. Individual Value Conversion
    // ----------------------------------------------------
    std.debug.print("\n3. Individual Value Conversion...\n", .{});

    // From Zig to Value
    var val = try zon.Value.from(allocator, @as(i32, 42));
    defer val.deinit(allocator);
    std.debug.print("Value from int: {}\n", .{val});

    // From Value to Zig
    const i = try val.to(allocator, i32);
    std.debug.print("Int from Value: {d}\n", .{i});
}
```

Actual output:

```bash
1. Creating ZON from struct...
Generated ZON:
.{
    .host = "127.0.0.1",
    .max_connections = 1000,
    .port = 8080,
    .ssl = true,
    .tags = .{
        "web",
        "api",
        "v1",
    },
}

2. Converting ZON back to struct...
Parsed Config:
  Host: 127.0.0.1
  Port: 8080
  SSL: true
  Max Conn: 1000
  Tags: web api v1

3. Individual Value Conversion...
Value from int: .{ .number = .{ .int = 42 } }
Int from Value: 42
```
