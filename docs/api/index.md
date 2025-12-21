---
title: "API Reference"
description: "Complete API reference for zon.zig: document creation, file utilities, update checking, version info, document methods, arrays, and more."
---

# API Overview

Complete API reference for zon.zig.

## Module Functions

Top-level functions exposed by the `zon` module.

### Document Creation

```zig
const zon = @import("zon");

// Create empty document
var doc = zon.create(allocator);

// Open file
var doc = try zon.open(allocator, "config.zon");

// Parse string
var doc = try zon.parse(allocator, source);
```

### File Utilities

```zig
// Check if file exists
if (zon.fileExists("config.zon")) { ... }

// Read file into allocator-owned buffer (caller frees)
const contents = try zon.readFile(allocator, "config.zon");
allocator.free(contents);

// Copy file (overwrite = true to replace destination)
try zon.copyFile("source.zon", "dest.zon", true);

// Move (rename) file (overwrite = true to replace destination)
try zon.moveFile("old.zon", "new.zon", true);

// Write atomically (writes to temp and renames)
try zon.writeFileAtomic(allocator, "out.zon", sourceData);

// Delete file
try zon.deleteFile("temp.zon");
```

### Update Checking

```zig
// Disable update notifications
zon.disableUpdateCheck();

// Enable update notifications
zon.enableUpdateCheck();

// Check if enabled
if (zon.isUpdateCheckEnabled()) { ... }

// Manual check
zon.checkForUpdates(allocator);
```

### Version

```zig
// Get version string
std.debug.print("Version: {s}\n", .{zon.version});
```

## Document Methods

### Getters

| Method                | Return          | Description          |
| --------------------- | --------------- | -------------------- |
| `getString(path)`     | `?[]const u8`   | Get string value     |
| `getIdentifier(path)` | `?[]const u8`   | Get identifier value |
| `getBool(path)`       | `?bool`         | Get boolean value    |
| `getInt(path)`        | `?i64`          | Get integer value    |
| `getFloat(path)`      | `?f64`          | Get float value      |
| `getNumber(path)`     | `?f64`          | Alias for getFloat   |
| `getValue(path)`      | `?*const Value` | Get raw Value        |

### Setters

| Method                       | Description               |
| ---------------------------- | ------------------------- |
| `setString(path, value)`     | Set string value          |
| `setIdentifier(path, value)` | Set identifier (`.value`) |
| `setBool(path, value)`       | Set boolean value         |
| `setInt(path, value)`        | Set integer value         |
| `setFloat(path, value)`      | Set float value           |
| `setNumber(path, value)`     | Alias for setFloat        |
| `setNull(path)`              | Set to null               |
| `setObject(path)`            | Create empty object       |
| `setArray(path)`             | Create empty array        |
| `setValue(path, value)`      | Set raw Value             |

### Checkers

| Method               | Return        | Description                  |
| -------------------- | ------------- | ---------------------------- |
| `exists(path)`       | `bool`        | Check if path exists         |
| `isNull(path)`       | `bool`        | Check if value is null       |
| `isIdentifier(path)` | `bool`        | Check if value is identifier |
| `getType(path)`      | `?[]const u8` | Get type name                |
| `isEmpty()`          | `bool`        | Check if document empty      |

### Modification

| Method         | Return          | Description         |
| -------------- | --------------- | ------------------- |
| `delete(path)` | `bool`          | Delete key          |
| `clear()`      | `void`          | Clear all data      |
| `count()`      | `usize`         | Number of root keys |
| `keys()`       | `![][]const u8` | Get all root keys   |

### Array Operations

| Method                            | Return          | Description         |
| --------------------------------- | --------------- | ------------------- |
| `arrayLen(path)`                  | `?usize`        | Get array length    |
| `getArrayElement(path, index)`    | `?*const Value` | Get element         |
| `getArrayString(path, index)`     | `?[]const u8`   | Get string element  |
| `getArrayInt(path, index)`        | `?i64`          | Get integer element |
| `getArrayBool(path, index)`       | `?bool`         | Get boolean element |
| `appendToArray(path, string)`     | `!void`         | Append string       |
| `appendIntToArray(path, int)`     | `!void`         | Append integer      |
| `appendFloatToArray(path, float)` | `!void`         | Append float        |
| `appendBoolToArray(path, bool)`   | `!void`         | Append boolean      |

### Find & Replace

| Method                        | Return          | Description                 |
| ----------------------------- | --------------- | --------------------------- |
| `findString(needle)`          | `![][]const u8` | Find paths containing       |
| `findExact(needle)`           | `![][]const u8` | Find paths with exact match |
| `replaceAll(find, replace)`   | `!usize`        | Replace all occurrences     |
| `replaceFirst(find, replace)` | `!bool`         | Replace first occurrence    |
| `replaceLast(find, replace)`  | `!bool`         | Replace last occurrence     |

### Merge & Clone

| Method         | Return          | Description          |
| -------------- | --------------- | -------------------- |
| `merge(other)` | `!void`         | Merge other document |
| `clone()`      | `!Document`     | Create deep copy     |
| `diff(other)`  | `![][]const u8` | Get differing keys   |

### Output

| Method                   | Return  | Description           |
| ------------------------ | ------- | --------------------- |
| `toString()`             | `![]u8` | 4-space indent        |
| `toCompactString()`      | `![]u8` | No indentation        |
| `toPrettyString(indent)` | `![]u8` | Custom indent         |
| `save()`                 | `!void` | Save to original path |
| `saveAs(path)`           | `!void` | Save to new path      |

### Cleanup

```zig
doc.deinit(); // Always call when done
```

## Value Types

### Value Union

```zig
pub const Value = union(enum) {
    null_val,
    bool_val: bool,
    number: Number,
    string: []const u8,
    identifier: []const u8,
    object: Object,
    array: Array,
};
```

### Value Methods

| Method              | Return        | Description         |
| ------------------- | ------------- | ------------------- |
| `asString()`        | `?[]const u8` | Get as string       |
| `asIdentifier()`    | `?[]const u8` | Get as identifier   |
| `asBool()`          | `?bool`       | Get as boolean      |
| `asInt()`           | `?i64`        | Get as integer      |
| `asFloat()`         | `?f64`        | Get as float        |
| `asObject()`        | `?*Object`    | Get as object       |
| `asArray()`         | `?*Array`     | Get as array        |
| `isNull()`          | `bool`        | Check if null       |
| `isIdentifier()`    | `bool`        | Check if identifier |
| `clone(allocator)`  | `!Value`      | Deep copy           |
| `deinit(allocator)` | `void`        | Free memory         |

## Error Types

### ParseError

```zig
pub const ParseError = error{
    UnexpectedToken,
    InvalidNumber,
    InvalidString,
    UnterminatedString,
    OutOfMemory,
};
```

## Type Name Strings

The `getType()` method returns these strings:

| Value             | Type String    |
| ----------------- | -------------- |
| `null`            | `"null"`       |
| `true`/`false`    | `"bool"`       |
| Integer           | `"int"`        |
| Float             | `"float"`      |
| `"string"`        | `"string"`     |
| `.identifier`     | `"identifier"` |
| `.{ ... }` object | `"object"`     |
| `.{ ... }` array  | `"array"`      |

## Quick Reference

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Create
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set
    try doc.setIdentifier("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setBool("debug", true);
    try doc.setFloat("rate", 0.05);
    try doc.setNull("password");

    // Nested
    try doc.setString("db.host", "localhost");
    try doc.setInt("db.port", 5432);

    // Arrays
    try doc.setArray("paths");
    try doc.appendToArray("paths", "src");
    try doc.appendToArray("paths", "lib");

    // Get
    const name = doc.getIdentifier("name").?;
    const port = doc.getInt("port").?;
    const len = doc.arrayLen("paths").?;

    // Check
    _ = doc.exists("port");
    _ = doc.isNull("password");
    _ = doc.isIdentifier("name");
    _ = doc.getType("port");

    // Modify
    _ = doc.delete("debug");

    // Output
    const output = try doc.toString();
    defer allocator.free(output);

    // Save
    try doc.saveAs("config.zon");
}
```
