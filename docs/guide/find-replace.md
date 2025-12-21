---
title: "Find & Replace"
description: "How to search and replace values across documents using zon.zig helper functions and strategies for precise matching."
---

# Find & Replace

zon.zig provides powerful find and replace capabilities to search and modify values throughout your document.

## Finding Values

### Find by Substring

Find all paths containing a specific string:

```zig
var doc = zon.create(allocator);
defer doc.deinit();

try doc.setString("server.host", "localhost");
try doc.setString("database.host", "localhost");
try doc.setString("cache.host", "192.168.1.100");

// Find all paths containing "localhost"
const results = try doc.findString("localhost");
defer {
    for (results) |r| allocator.free(r);
    allocator.free(results);
}

// results contains: ["server.host", "database.host"]
std.debug.print("Found {d} matches\n", .{results.len});
```

### Find Exact Match

Find paths with an exact value match:

```zig
const exact = try doc.findExact("localhost");
defer {
    for (exact) |e| allocator.free(e);
    allocator.free(exact);
}
```

## Finding Keys

You can search for keys anywhere in the document tree recursively.

### Find First Key

Returns the `*Value` of the first matching key found:

```zig
if (doc.find("port")) |val| {
    std.debug.print("Found port: {any}\n", .{val});
}
```

### Find All Keys

Returns a list of all paths where the key exists (e.g. `server.port`, `db.port`):

```zig
const paths = try doc.findAll("port");
defer {
    for (paths) |p| allocator.free(p);
    allocator.free(paths);
}
```

## Replacing Values

### Replace All

Replace all occurrences of a value:

```zig
// Replace all "localhost" with "production.example.com"
const count = try doc.replaceAll("localhost", "production.example.com");
std.debug.print("Replaced {d} occurrences\n", .{count});
```

### Replace First

Replace only the first occurrence:

```zig
const replaced = try doc.replaceFirst("old_value", "new_value");
if (replaced) {
    std.debug.print("First occurrence replaced\n", .{});
}
```

### Replace Last

Replace only the last occurrence:

```zig
const replaced = try doc.replaceLast("old_value", "new_value");
if (replaced) {
    std.debug.print("Last occurrence replaced\n", .{});
}
```

## Practical Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var config = zon.create(allocator);
    defer config.deinit();

    // Setup configuration with localhost references
    try config.setString("server.host", "localhost");
    try config.setString("server.backup", "localhost");
    try config.setString("database.host", "localhost");
    try config.setString("cache.host", "localhost");

    std.debug.print("Before:\n", .{});
    const before = try config.toString();
    defer allocator.free(before);
    std.debug.print("{s}\n", .{before});

    // Update for production
    const count = try config.replaceAll("localhost", "prod.example.com");
    std.debug.print("\nReplaced {d} values\n", .{count});

    std.debug.print("\nAfter:\n", .{});
    const after = try config.toString();
    defer allocator.free(after);
    std.debug.print("{s}\n", .{after});
}
```
