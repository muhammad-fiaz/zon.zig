---
title: "What is zon.zig?"
description: "Overview of zon.zig: a small, direct Zig library for reading and writing ZON (Zig Object Notation) files, designed for config files and manifests."
---

# What is zon.zig?

A simple, direct Zig library for reading and writing ZON (Zig Object Notation) files.

## Overview

zon.zig provides a high-level API for working with ZON files without relying on Zig compiler internals. It's designed for configuration files, package manifests, and structured data.

## Key Features

| Feature                 | Description                                    |
| ----------------------- | ---------------------------------------------- |
| **Simple API**          | Intuitive getter/setter interface              |
| **Nested Paths**        | Access deep values with `"server.ssl.enabled"` |
| **Identifier Values**   | Support `.name = .value` syntax                |
| **Auto-create Objects** | Intermediate objects created automatically     |
| **Find & Replace**      | Search and replace across documents            |
| **Merge & Clone**       | Combine and duplicate documents                |
| **Pretty Print**        | Configurable output formatting                 |
| **No Dependencies**     | Pure Zig, no external libraries                |

## Use Cases

- **Configuration files** - Application settings
- **Package manifests** - `build.zig.zon` parsing
- **Data storage** - Structured data persistence
- **Migration tools** - Convert between formats

## Quick Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Create document
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set values
    try doc.setIdentifier("name", "my_app");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);

    // Nested paths (auto-creates intermediate objects)
    try doc.setString("database.host", "localhost");
    try doc.setInt("database.port", 5432);

    // Arrays
    try doc.setArray("paths");
    try doc.appendToArray("paths", "src");
    try doc.appendToArray("paths", "lib");

    // Output
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});
}
```

**Output:**

```zig
.{
    .database = .{
        .host = "localhost",
        .port = 5432,
    },
    .name = .my_app,
    .paths = .{
        "src",
        "lib",
    },
    .port = 8080,
    .version = "1.0.0",
}
```

## Supported ZON Syntax

| Syntax      | Example               |
| ----------- | --------------------- |
| Strings     | `"hello"`             |
| Identifiers | `.my_package`         |
| Integers    | `42`, `0xFF`, `0o755` |
| Floats      | `3.14`                |
| Booleans    | `true`, `false`       |
| Null        | `null`                |
| Objects     | `.{ .key = value }`   |
| Arrays      | `.{ "a", "b" }`       |
| Comments    | `// comment`          |

## API Style

All getters return optionals for safe access:

```zig
const name = doc.getString("name") orelse "default";
const port = doc.getInt("port") orelse 8080;

if (doc.exists("database.host")) {
    // ...
}
```

All setters can return errors for allocation failures:

```zig
try doc.setString("key", "value");
try doc.setInt("port", 8080);
```

## Comparison with Alternatives

| Feature             | zon.zig | std.zig.Ast |
| ------------------- | ------- | ----------- |
| High-level API      | ✅      | ❌          |
| Nested paths        | ✅      | ❌          |
| Auto-create objects | ✅      | ❌          |
| Find/replace        | ✅      | ❌          |
| Identifier values   | ✅      | ✅          |
| Memory safe         | ✅      | ✅          |

## Requirements

- Zig 0.15.0 or later
- No external dependencies

## Next Steps

- [Getting Started](./getting-started.md) - Installation and setup
- [Basic Usage](./basic-usage.md) - Core operations
- [API Reference](../api/) - Complete API documentation
