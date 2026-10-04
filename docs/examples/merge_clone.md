---
title: "Merge and Clone Example"
description: "Shallow and deep document merges, deep equality, and independent deep copies."
---

# Merge & Clone Example

**Usecase:** layer an override document over a base config (`merge`,
`mergeRecursive`), prove the result with deep equality (`eql`), and fork
independent copies (`clone`) that can diverge safely.

**Run:** `zig build run-merge_clone`

```zig
const std = @import("std");
const zon = @import("zon");

/// Example: Merging and cloning documents
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Merge and Clone Example ===\n\n", .{});

    var base = zon.create(allocator);
    defer base.deinit();

    try base.setString("name", "myapp");
    try base.setString("version", "1.0.0");
    try base.setInt("port", 8080);
    try base.setString("database.host", "localhost");

    std.debug.print("Base document:\n", .{});
    const baseStr = try base.toString();
    defer allocator.free(baseStr);
    std.debug.print("{s}\n\n", .{baseStr});

    var override = zon.create(allocator);
    defer override.deinit();

    try override.setInt("port", 9000);
    try override.setString("database.host", "production.example.com");
    try override.setString("database.password", "secret123");
    try override.setBool("debug", false);

    std.debug.print("Override document:\n", .{});
    const overrideStr = try override.toString();
    defer allocator.free(overrideStr);
    std.debug.print("{s}\n\n", .{overrideStr});

    std.debug.print("=== Merging override into base ===\n", .{});
    try base.merge(&override);

    const mergedStr = try base.toString();
    defer allocator.free(mergedStr);
    std.debug.print("{s}\n\n", .{mergedStr});

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
```

```bash
=== Merge and Clone Example ===

Base document:
.{
    .database = .{
        .host = "localhost",
    },
    .name = "myapp",
    .port = 8080,
    .version = "1.0.0",
}

Override document:
.{
    .database = .{
        .host = "production.example.com",
        .password = "secret123",
    },
    .debug = false,
    .port = 9000,
}

=== Merging override into base ===
.{
    .database = .{
        .host = "production.example.com",
        .password = "secret123",
    },
    .debug = false,
    .name = "myapp",
    .port = 9000,
    .version = "1.0.0",
}

=== Cloning document ===
Original after clone modification:
  name: myapp
  version: 1.0.0

Cloned document:
  name: myapp-clone
  version: 2.0.0

Clone is independent from original!
```
