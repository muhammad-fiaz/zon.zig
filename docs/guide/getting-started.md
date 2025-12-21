---
title: "Getting Started"
description: "Learn how to install and use zon.zig in your Zig project — includes installation, quick start examples, reading, writing, arrays, and identifier values."
---

# Getting Started

Learn how to install and use zon.zig in your Zig project.

## Requirements

- **Zig 0.15.0** or later

## Installation

### Using Zig Package Manager

Add zon.zig as a dependency in your `build.zig.zon`:

```zig
.dependencies = .{
    .zon = .{
        .url = "https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.3.tar.gz",
        .hash = "...", // Will be provided by `zig fetch`
    },
},
```

Or use the `zig fetch` command:

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.3.tar.gz
```

Then update your `build.zig`:

```zig
const zon_dep = b.dependency("zon", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zon", zon_dep.module("zon"));
```

## Quick Start

### Create and Save a Document

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Disable update checking (optional)
    zon.disableUpdateCheck();

    // Create a new document
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set values
    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setBool("debug", true);

    // Set nested values (auto-creates intermediate objects)
    try doc.setString("database.host", "localhost");
    try doc.setInt("database.port", 5432);

    // Save to file
    try doc.saveAs("config.zon");
}
```

**Output (`config.zon`):**

```zig
.{
    .database = .{
        .host = "localhost",
        .port = 5432,
    },
    .debug = true,
    .name = "myapp",
    .port = 8080,
    .version = "1.0.0",
}
```

### Open and Read a Document

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Open existing file
    var doc = try zon.open(allocator, "config.zon");
    defer doc.close(); // or doc.deinit();

    // Read values
    const name = doc.getString("name") orelse "unknown";
    const port = doc.getInt("port") orelse 8080;
    const debug = doc.getBool("debug") orelse false;

    std.debug.print("App: {s}\n", .{name});
    std.debug.print("Port: {d}\n", .{port});
    std.debug.print("Debug: {}\n", .{debug});

    // Read nested values
    if (doc.getString("database.host")) |host| {
        std.debug.print("DB Host: {s}\n", .{host});
    }
}
```

**Output:**

```
App: myapp
Port: 8080
Debug: true
DB Host: localhost
```

### Parse from String

```zig
const source =
    \\.{
    \\    .name = "myapp",
    \\    .version = "1.0.0",
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

std.debug.print("Name: {s}\n", .{doc.getString("name").?});
```

### Working with Identifier Values

ZON supports identifier values like `.name = .my_package`:

```zig
// Set identifier (outputs as .name = .my_package)
try doc.setIdentifier("name", "my_package");

// Read identifier
if (doc.getIdentifier("name")) |id| {
    std.debug.print("Package: .{s}\n", .{id});
}

// Check if value is an identifier
if (doc.isIdentifier("name")) {
    std.debug.print("name is an identifier\n", .{});
}
```

### Working with Arrays

```zig
// Create array
try doc.setArray("paths");

// Append items
try doc.appendToArray("paths", "build.zig");
try doc.appendToArray("paths", "src");

// Read array
const len = doc.arrayLen("paths").?;
std.debug.print("Paths: {d} items\n", .{len});

var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("  - {s}\n", .{path});
}
```

## API Overview

| Function                       | Description                  |
| ------------------------------ | ---------------------------- |
| `zon.create(allocator)`        | Create empty document        |
| `zon.open(allocator, path)`    | Open file                    |
| `zon.parse(allocator, source)` | Parse string                 |
| `zon.fileExists(path)`         | Check if file exists         |
| `zon.copyFile(src, dst)`       | Copy file                    |
| `zon.deleteFile(path)`         | Delete file                  |
| `zon.renameFile(old, new)`     | Rename file                  |
| `zon.disableUpdateCheck()`     | Disable update notifications |
| `zon.version`                  | Library version string       |

## Next Steps

- [Basic Usage](./basic-usage.md) - Core operations
- [Reading Files](./reading.md) - File reading in depth
- [Writing Files](./writing.md) - File writing in depth
- [Identifier Values](./identifier-values.md) - `.name = .value` syntax
- [API Reference](../api/) - Complete API documentation
