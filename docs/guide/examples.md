---
title: "Examples"
description: "Usage examples demonstrating common zon.zig tasks: configuration files, nested paths, arrays, merging, and pretty printing."
---

# Examples

This page provides complete, runnable examples for common use cases.

## Running Examples

```bash
# Run specific example
zig build run-basic
zig build run-package_manifest
zig build run-find_replace
zig build run-arrays
zig build run-pretty_print
zig build run-merge_clone
zig build run-config_management
zig build run-error_handling
zig build run-nested_creation
zig build run-identifier_values
zig build run-file_operations

# Run all examples
zig build run-all-examples
```

## Basic Example

Create, modify, and save a ZON document:

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

    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setBool("private", true);
    try doc.setInt("port", 8080);

    try doc.setString("dependencies.http.path", "../http");
    try doc.setString("dependencies.json.path", "../json");

    std.debug.print("Name: {s}\n", .{doc.getString("name").?});
    std.debug.print("Port: {d}\n", .{doc.getInt("port").?});

    try doc.saveAs("config.zon");
}
```

## Parsing build.zig.zon

Parse and modify a Zig package manifest:

```zig
const source =
    \\.{
    \\    .name = .my_package,
    \\    .version = "0.1.0",
    \\    .fingerprint = 0xee480fa30d50cbf6,
    \\    .paths = .{
    \\        "build.zig",
    \\        "src",
    \\    },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Read identifier value (stored as string)
std.debug.print("Name: {s}\n", .{doc.getString("name").?});

// Read fingerprint
if (doc.getInt("fingerprint")) |fp| {
    std.debug.print("Fingerprint: 0x{x}\n", .{@as(u64, @bitCast(fp))});
}

// Read array
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("Path: {s}\n", .{path});
}
```

## Nested ZON Creation

Create deeply nested configuration structures:

```zig
var doc = zon.create(allocator);
defer doc.deinit();

// Level 1
try doc.setString("name", "myapp");

// Level 2
try doc.setString("server.host", "0.0.0.0");
try doc.setInt("server.port", 8080);

// Level 3
try doc.setBool("server.ssl.enabled", true);
try doc.setString("server.ssl.cert_path", "/etc/ssl/cert.pem");
try doc.setInt("server.ssl.port", 443);

// Level 3 - Different branch
try doc.setInt("database.pool.min_size", 5);
try doc.setInt("database.pool.max_size", 20);

// Dependencies
try doc.setString("dependencies.http.url", "https://example.com/http");
try doc.setString("dependencies.http.hash", "abc123");
```

Result:

```zig
.{
    .database = .{
        .pool = .{
            .max_size = 20,
            .min_size = 5,
        },
    },
    .dependencies = .{
        .http = .{
            .hash = "abc123",
            .url = "https://example.com/http",
        },
    },
    .name = "myapp",
    .server = .{
        .host = "0.0.0.0",
        .port = 8080,
        .ssl = .{
            .cert_path = "/etc/ssl/cert.pem",
            .enabled = true,
            .port = 443,
        },
    },
}
```

## Find and Replace

Search and replace values:

```zig
try doc.setString("server.host", "localhost");
try doc.setString("database.host", "localhost");

// Find all paths containing "localhost"
const found = try doc.findString("localhost");
defer {
    for (found) |f| allocator.free(f);
    allocator.free(found);
}
std.debug.print("Found {d} matches\n", .{found.len});

// Replace all occurrences
const count = try doc.replaceAll("localhost", "production.example.com");
std.debug.print("Replaced {d} values\n", .{count});
```

## Array Operations

Work with ZON arrays:

```zig
// Create and populate array
try doc.setArray("paths");
try doc.appendToArray("paths", "build.zig");
try doc.appendToArray("paths", "src");

// Read array
std.debug.print("Length: {d}\n", .{doc.arrayLen("paths").?});
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("{s}\n", .{path});
}
```

## Error Handling

Safe parsing with error handling:

```zig
// Parse with error handling
var doc = zon.parse(allocator, source) catch |err| {
    std.debug.print("Parse error: {}\n", .{err});
    return;
};
defer doc.deinit();

// Open file with error handling
var file_doc = zon.open(allocator, "config.zon") catch |err| {
    std.debug.print("File error: {}\n", .{err});
    return;
};
defer file_doc.deinit();

// Safe value access with defaults
const name = doc.getString("name") orelse "default";
const port = doc.getInt("port") orelse 8080;
```

## File Operations

zon.zig provides helpers for safe file I/O and common file workflows:

```zig
// Read file into allocator-owned buffer
const contents = try zon.readFile(allocator, "config.zon");
allocator.free(contents);

// Atomic write (write to temp, then rename)
try zon.writeFileAtomic(allocator, "config.zon", data);

// Per-document helpers
try doc.saveAsAtomic("config.zon"); // atomic save
try doc.saveWithBackup(".bak");     // moves existing to config.zon.bak then saves
const wrote = try doc.saveIfChanged(); // only writes if contents differ

// Copy and move with overwrite control
try zon.copyFile("a.zon", "b.zon", true);
try zon.moveFile("b.zon", "c.zon", true);

// Parse directly from a file
var doc = try zon.parseFile(allocator, "config.zon");
defer doc.deinit();
```

Sample console output from running the file operations example:

```text
Saving document atomically to example_a.zon
Read 123 bytes from example_a.zon
Copying example_a.zon -> example_b.zon
Renaming example_b.zon -> example_c.zon
saveIfChanged wrote file? yes
Atomically writing parsed document to stringified.zon
File operations demo completed successfully.
```


## Configuration Management

Create dev/prod configurations:

```zig
// Development config
var dev = zon.create(allocator);
defer dev.deinit();

try dev.setString("environment", "development");
try dev.setString("database.host", "localhost");
try dev.setBool("debug", true);

// Clone for production
var prod = try dev.clone();
defer prod.deinit();

// Apply production overrides
try prod.setString("environment", "production");
try prod.setString("database.host", "db.example.com");
try prod.setBool("debug", false);
```

## Pretty Print

Output with different formatting:

```zig
// Default (4-space)
const output = try doc.toString();
defer allocator.free(output);

// 2-space indent
const two_space = try doc.toPrettyString(2);
defer allocator.free(two_space);

// Compact
const compact = try doc.toCompactString();
defer allocator.free(compact);
```

## Available Examples

| Example             | Description           | Command                           |
| ------------------- | --------------------- | --------------------------------- |
| `basic`             | Core operations       | `zig build run-basic`             |
| `package_manifest`  | build.zig.zon format  | `zig build run-package_manifest`  |
| `find_replace`      | Search and replace    | `zig build run-find_replace`      |
| `arrays`            | Array operations      | `zig build run-arrays`            |
| `pretty_print`      | Output formatting     | `zig build run-pretty_print`      |
| `merge_clone`       | Document merging      | `zig build run-merge_clone`       |
| `config_management` | Dev/prod configs      | `zig build run-config_management` |
| `error_handling`    | Error handling        | `zig build run-error_handling`    |
| `nested_creation`   | Deep nesting          | `zig build run-nested_creation`   |
| `identifier_values` | .name = .value syntax | `zig build run-identifier_values` |
| `file_operations`   | Safe atomic writes, backups, read/write helpers | `zig build run-file_operations` |
