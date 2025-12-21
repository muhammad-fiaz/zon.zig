---
title: "Array Operations"
description: "Array operations in ZON documents: create arrays, append items, read elements, and manage array length."
---

# Array Operations

zon.zig supports working with ZON arrays, including reading, creating, and appending to arrays.

## Reading Arrays

### Get Array Length

```zig
const source =
    \\.{
    \\    .paths = .{
    \\        "build.zig",
    \\        "src",
    \\        "README.md",
    \\    },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

const len = doc.arrayLen("paths"); // 3
```

### Get Array Elements

```zig
// Get string at specific index
const first = doc.getArrayString("paths", 0); // "build.zig"
const second = doc.getArrayString("paths", 1); // "src"

// Iterate through array
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("Path: {s}\n", .{path});
}
```

### Get Element as Value

```zig
// Get raw Value pointer
const elem = doc.getArrayElement("paths", 0);
if (elem) |e| {
    if (e.asString()) |s| {
        std.debug.print("String: {s}\n", .{s});
    }
}
```

## Creating Arrays

### Create Empty Array

```zig
var doc = zon.create(allocator);
defer doc.deinit();

// Create empty array at path
try doc.setArray("items");
```

### Append to Array

```zig
// Append strings
try doc.appendToArray("items", "first");
try doc.appendToArray("items", "second");
try doc.appendToArray("items", "third");

// Append integers
try doc.setArray("numbers");
try doc.appendIntToArray("numbers", 1);
try doc.appendIntToArray("numbers", 2);
try doc.appendIntToArray("numbers", 3);

// Insert at specific index
try doc.insertStringIntoArray("items", 0, "zeroth");

// Remove from specific index
_ = doc.removeFromArray("items", 1);
```

## Advanced Array Operations

### Finding Elements

Use `indexOf` to find the first occurrence of a string value in an array:

```zig
if (doc.indexOf("items", "second")) |index| {
    std.debug.print("Found 'second' at index {d}\n", .{index});
}
```

### Counting Items at Path

`countAt` works on both objects (counting keys) and arrays (counting elements):

```zig
const count = doc.countAt("items");
std.debug.print("Array has {d} items\n", .{count});
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

    // Parse build.zig.zon style array
    const source =
        \\.{
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\    },
        \\}
    ;

    var doc = try zon.parse(allocator, source);
    defer doc.deinit();

    // Read existing array
    std.debug.print("Original paths ({d} items):\n", .{doc.arrayLen("paths").?});
    var i: usize = 0;
    while (doc.getArrayString("paths", i)) |path| : (i += 1) {
        std.debug.print("  - {s}\n", .{path});
    }

    // Append new items
    try doc.appendToArray("paths", "src");
    try doc.appendToArray("paths", "README.md");
    try doc.appendToArray("paths", "LICENSE");

    std.debug.print("\nAfter appending ({d} items):\n", .{doc.arrayLen("paths").?});
    i = 0;
    while (doc.getArrayString("paths", i)) |path| : (i += 1) {
        std.debug.print("  - {s}\n", .{path});
    }

    // Create new array
    try doc.setArray("tags");
    try doc.appendToArray("tags", "stable");
    try doc.appendToArray("tags", "0.0.3");

    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("\nFinal ZON:\n{s}\n", .{output});
}
```

## build.zig.zon Format

zon.zig fully supports the build.zig.zon array format:

```zig
.{
    .name = .my_package,
    .version = "0.1.0",
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

Read with:

```zig
const name = doc.getString("name"); // "my_package"
const paths_len = doc.arrayLen("paths"); // 3
const first_path = doc.getArrayString("paths", 0); // "build.zig"
```
