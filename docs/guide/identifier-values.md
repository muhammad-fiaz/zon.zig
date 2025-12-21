---
title: "Identifier Values"
description: "Working with ZON identifier values (e.g., `.name = .value`): how to set, detect, and read identifier values."
---

# Identifier Values

ZON supports identifier values like `.name = .my_package`. This is common in `build.zig.zon` files.

## API Methods

| Method                       | Description                                |
| ---------------------------- | ------------------------------------------ |
| `getIdentifier(path)`        | Get identifier value (or null)             |
| `setIdentifier(path, value)` | Set identifier value (outputs as `.value`) |
| `isIdentifier(path)`         | Check if value is an identifier            |
| `getString(path)`            | Also works for identifiers                 |

## Setting Identifier Values

Use `setIdentifier` to create values that output as `.value`:

```zig
var doc = zon.create(allocator);
defer doc.deinit();

// Use setIdentifier for .name = .value syntax
try doc.setIdentifier("name", "my_package");
try doc.setString("version", "1.0.0");

const output = try doc.toString();
```

Output:

```zig
.{
    .name = .my_package,
    .version = "1.0.0",
}
```

## Reading Identifier Values

Use `getIdentifier` for identifier-specific access:

```zig
const source =
    \\.{
    \\    .name = .my_package,
    \\    .version = "1.0.0",
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Get identifier (returns "my_package")
const name = doc.getIdentifier("name").?;
std.debug.print("Name: .{s}\n", .{name});

// getString also works
const name2 = doc.getString("name").?;

// Check type
if (doc.isIdentifier("name")) {
    std.debug.print("name is an identifier\n", .{});
}

// getType returns "identifier"
const t = doc.getType("name").?; // "identifier"
```

## Comparison: String vs Identifier

| Method                         | Set        | Parsed     | Output          |
| ------------------------------ | ---------- | ---------- | --------------- |
| `setString("name", "foo")`     | String     | String     | `.name = "foo"` |
| `setIdentifier("name", "foo")` | Identifier | Identifier | `.name = .foo`  |

When parsing:

| ZON Syntax      | Type       | `getIdentifier` | `getString` |
| --------------- | ---------- | --------------- | ----------- |
| `.name = .foo`  | Identifier | `"foo"`         | `"foo"`     |
| `.name = "foo"` | String     | `null`          | `"foo"`     |

## Parsing build.zig.zon

```zig
const source =
    \\.{
    \\    .name = .downloader,
    \\    .version = "0.1.0",
    \\    .fingerprint = 0xee480fa30d50cbf6,
    \\    .minimum_zig_version = "0.15.0",
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src",
    \\    },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Read identifier
if (doc.getIdentifier("name")) |name| {
    std.debug.print("Package: .{s}\n", .{name});
}

// Check type
std.debug.print("Type: {s}\n", .{doc.getType("name").?}); // "identifier"

// Read fingerprint (large hex)
if (doc.getInt("fingerprint")) |fp| {
    const unsigned: u64 = @bitCast(fp);
    std.debug.print("Fingerprint: 0x{x}\n", .{unsigned});
}

// Read array
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("Path: {s}\n", .{path});
}
```

## Creating build.zig.zon Format

```zig
var doc = zon.create(allocator);
defer doc.deinit();

// Package name as identifier
try doc.setIdentifier("name", "my_lib");
try doc.setString("version", "0.1.0");
try doc.setString("minimum_zig_version", "0.15.0");

// Fingerprint
const fp: u64 = 0xaabbccdd11223344;
try doc.setInt("fingerprint", @bitCast(fp));

// Paths array
try doc.setArray("paths");
try doc.appendToArray("paths", "build.zig");
try doc.appendToArray("paths", "build.zig.zon");
try doc.appendToArray("paths", "src");

// Dependencies
try doc.setString("dependencies.http.url", "https://example.com/http");
try doc.setString("dependencies.http.hash", "abc123def456");

try doc.saveAs("build.zig.zon");
```

Output:

```zig
.{
    .dependencies = .{
        .http = .{
            .hash = "abc123def456",
            .url = "https://example.com/http",
        },
    },
    .fingerprint = -6144092016769617084,
    .minimum_zig_version = "0.15.0",
    .name = .my_lib,
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
    .version = "0.1.0",
}
```

## Run Example

```bash
zig build run-identifier_values
```
