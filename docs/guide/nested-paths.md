---
title: "Nested Paths"
description: "Details on using dot-notation nested paths, accessing deep values, and auto-creating intermediate objects."
---

# Nested Paths

zon.zig uses dot notation to access nested values in ZON documents.

## Path Syntax

Paths use `.` as the separator:

- `"name"` - Top-level key
- `"config.port"` - Nested key
- `"config.database.host"` - Deeply nested key

## Auto-Creation

When setting values, intermediate objects are created automatically:

```zig
var doc = zon.create(allocator);
defer doc.deinit();

// Creates the full path: .{ .config = .{ .database = .{ .host = "localhost" } } }
try doc.setString("config.database.host", "localhost");
```

This is equivalent to:

```zig
.{
    .config = .{
        .database = .{
            .host = "localhost",
        },
    },
}
```

## Reading Nested Values

```zig
const host = doc.getString("config.database.host"); // "localhost"
const port = doc.getInt("config.database.port");    // null if not set

// Use orelse for defaults
const timeout = doc.getInt("config.database.timeout") orelse 30;
```

## Setting Multiple Nested Values

```zig
try doc.setString("server.host", "0.0.0.0");
try doc.setInt("server.port", 8080);
try doc.setBool("server.ssl.enabled", true);
try doc.setString("server.ssl.cert", "/etc/ssl/cert.pem");

try doc.setString("database.host", "localhost");
try doc.setInt("database.port", 5432);
try doc.setString("database.name", "myapp");
try doc.setString("database.username", "admin");
```

Result:

```zig
.{
    .database = .{
        .host = "localhost",
        .name = "myapp",
        .port = 5432,
        .username = "admin",
    },
    .server = .{
        .host = "0.0.0.0",
        .port = 8080,
        .ssl = .{
            .cert = "/etc/ssl/cert.pem",
            .enabled = true,
        },
    },
}
```

## Deleting Nested Keys

```zig
// Delete a nested key
const deleted = doc.delete("server.ssl.enabled");

// Delete an entire nested object
const deleted_obj = doc.delete("database");
```

## Checking Nested Paths

```zig
// Check if nested path exists
if (doc.exists("config.database.host")) {
    // Path exists
}

// Get type of nested value
const type_name = doc.getType("config.database.port"); // "int"
```

## Accessing Nested Objects

Get a reference to a nested object for direct manipulation:

```zig
if (doc.getObject("config.database")) |db_obj| {
    // Work with the database object directly
    _ = db_obj;
}
```

## Example: Dependencies

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set package info
    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");

    // Set dependencies with nested paths
    try doc.setString("dependencies.http.url", "https://github.com/example/http");
    try doc.setString("dependencies.http.hash", "abc123");

    try doc.setString("dependencies.json.url", "https://github.com/example/json");
    try doc.setString("dependencies.json.hash", "def456");

    try doc.setString("dependencies.crypto.url", "https://github.com/example/crypto");
    try doc.setString("dependencies.crypto.hash", "ghi789");

    // Read back
    std.debug.print("HTTP URL: {s}\n", .{doc.getString("dependencies.http.url").?});
    std.debug.print("JSON URL: {s}\n", .{doc.getString("dependencies.json.url").?});

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("\n{s}\n", .{output});
}
```

Output:

```zig
.{
    .dependencies = .{
        .crypto = .{
            .hash = "ghi789",
            .url = "https://github.com/example/crypto",
        },
        .http = .{
            .hash = "abc123",
            .url = "https://github.com/example/http",
        },
        .json = .{
            .hash = "def456",
            .url = "https://github.com/example/json",
        },
    },
    .name = "myapp",
    .version = "1.0.0",
}
```
