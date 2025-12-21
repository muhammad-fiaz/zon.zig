---
title: "What is zon.zig?"
description: "Overview of zon.zig: a document-based Zig library for reading, writing, and manipulating ZON (Zig Object Notation) files — complementary to std.zon."
---

# What is zon.zig?

A document-based Zig library for reading, writing, and manipulating ZON (Zig Object Notation) files.

## Overview

zon.zig provides a **document-based API** (DOM-like) for working with ZON files. Unlike [Zig's standard library `std.zon`](https://codeberg.org/ziglang/zig/src/branch/master/lib/std/zon) which parses ZON directly into typed Zig structures at compile-time or runtime, zon.zig maintains an in-memory document tree that you can query, modify, and serialize.

This approach makes zon.zig ideal for:

- **Configuration file editing** where you need to modify values and save back
- **Dynamic access** when the structure isn't known at compile time
- **Find/Replace operations** across documents
- **Advanced Merging** of configurations from multiple sources
- **Deep Equality** checks between documents

## zon.zig vs Zig's std.zon

| Feature            | zon.zig                               | std.zon                             |
| ------------------ | ------------------------------------- | ----------------------------------- |
| **Approach**       | Document-based (DOM tree)             | Type-based (direct deserialization) |
| **Parse Target**   | Intermediate `Value` tree             | Zig types (`struct`, `enum`, etc.)  |
| **Use Case**       | Config editing, dynamic access        | Type-safe parsing into known types  |
| **Modification**   | **Full read/write/edit/merge**        | Read-only (serialize separately)    |
| **Path Access**    | **Dot notation (`"db.host"`)**        | Field access on typed structs       |
| **Dependencies**   | **Custom parser (no Ast dependency)** | Uses `std.zig.Ast`, `Zoir`          |
| **Special Values** | **NaN, Inf, -Inf support**            | Limited in some Zig versions        |
| **Compile-time**   | Runtime only                          | Supports `@import` for ZON          |
| **Memory**         | Heap-allocated document tree          | Can use fixed buffers               |

### When to Use zon.zig

```zig
// zon.zig: Document-based, dynamic access
var doc = try zon.open(allocator, "config.zon");
try doc.setString("server.host", "newhost.com");  // Modify
try doc.save();  // Write back
```

### When to Use std.zon

```zig
// std.zon: Type-based, compile-time safe (Zig 0.15+)
const Config = struct { server: struct { host: []const u8 } };
const config = try std.zon.fromSlice(Config, allocator, source, null, .{});
// Direct field access: config.server.host
```

## Key Features

| Feature                 | Description                                    |
| ----------------------- | ---------------------------------------------- |
| **Simple API**          | Intuitive getter/setter interface              |
| **Nested Paths**        | Access deep values with `"server.ssl.enabled"` |
| **Identifier Values**   | Support `.name = .value` syntax                |
| **Auto-create Objects** | Intermediate objects created automatically     |
| **Find & Replace**      | Search and replace across documents            |
| **Merge (Deep)**        | **Recursive merging** of nested configurations |
| **Deep Equality**       | **Deep comparison** between two documents      |
| **Multi-line Strings**  | Support for **backslash syntax** (`\\`)        |
| **Special Floats**      | Handle **inf, -inf, and nan** values           |
| **Pretty Print**        | Configurable output formatting                 |
| **No Dependencies**     | Custom parser, no `std.zig.Ast` required       |

## Use Cases

- **Configuration editors** - Modify and save config files programmatically
- **Package manifests** - Read/write `build.zig.zon` files
- **Config merging** - Combine base + environment-specific settings recursively
- **Migration tools** - Transform configuration formats
- **Dynamic configs** - When structure is determined at runtime

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

## Feature Comparison

| Feature             | zon.zig | std.zon |
| ------------------- | ------- | ------- |
| Document editing    | ✅      | ❌      |
| Path-based access   | ✅      | ❌      |
| Auto-create objects | ✅      | ❌      |
| Find/replace        | ✅      | ❌      |
| Merge documents     | ✅      | ❌      |
| Type-safe parsing   | ❌      | ✅      |
| Compile-time import | ❌      | ✅      |
| Identifier values   | ✅      | ✅      |
| Memory safe         | ✅      | ✅      |

> **Note:** `std.zon` (available in Zig 0.15+) is better for deserializing into known types.
> zon.zig is better for editing and manipulating configuration files dynamically.

## Requirements

- Zig 0.15.0 or later
- No external dependencies

## Next Steps

- [Getting Started](./getting-started.md) - Installation and setup
- [Basic Usage](./basic-usage.md) - Core operations
- [API Reference](../api/) - Complete API documentation
