---
title: "Document"
description: "Document struct API: methods for initialization, getters, setters, arrays, find & replace, merge & clone, and persistence."
---

# Document

The `Document` struct represents a parsed ZON document and provides methods for reading, writing, searching, and saving.

## Initialization

### Create Empty Document

```zig
var doc = zon.create(allocator);
defer doc.deinit();
```

### Open From File

```zig
var doc = try zon.open(allocator, "config.zon");
defer doc.deinit();
```

### Parse From String

```zig
var doc = try zon.parse(allocator, source);
defer doc.deinit();
```

## Getters

All getters return `null` for missing paths or type mismatches.

| Method                | Return Type     | Description                  |
| --------------------- | --------------- | ---------------------------- |
| `getString(path)`     | `?[]const u8`   | Get string value             |
| `getIdentifier(path)` | `?[]const u8`   | Get identifier value         |
| `getBool(path)`       | `?bool`         | Get boolean value            |
| `getInt(path)`        | `?i64`          | Get integer value            |
| `getFloat(path)`      | `?f64`          | Get float value              |
| `getNumber(path)`     | `?f64`          | Alias for getFloat           |
| `getValue(path)`      | `?*const Value` | Get raw Value                |
| `isNull(path)`        | `bool`          | Check if value is null       |
| `isIdentifier(path)`  | `bool`          | Check if value is identifier |
| `exists(path)`        | `bool`          | Check if path exists         |
| `getType(path)`       | `?[]const u8`   | Get type name                |

## Setters

All setters auto-create intermediate objects.

| Method                       | Description               |
| ---------------------------- | ------------------------- |
| `setString(path, value)`     | Set string value          |
| `setIdentifier(path, value)` | Set identifier (`.value`) |
| `setBool(path, value)`       | Set boolean value         |
| `setInt(path, value)`        | Set integer value         |
| `setFloat(path, value)`      | Set float value           |
| `setNumber(path, value)`     | Alias for setFloat        |
| `setNull(path)`              | Set value to null         |
| `setObject(path)`            | Create empty object       |
| `setArray(path)`             | Create empty array        |
| `setValue(path, value)`      | Set raw Value             |

## Modification

| Method         | Return          | Description                         |
| -------------- | --------------- | ----------------------------------- |
| `delete(path)` | `bool`          | Delete key, returns true if existed |
| `clear()`      | `void`          | Clear all data                      |
| `count()`      | `usize`         | Number of root keys                 |
| `keys()`       | `![][]const u8` | All root keys (caller frees)        |
| `isEmpty()`    | `bool`          | Check if document is empty          |

## Array Operations

| Method                            | Return          | Description          |
| --------------------------------- | --------------- | -------------------- |
| `arrayLen(path)`                  | `?usize`        | Get array length     |
| `getArrayElement(path, index)`    | `?*const Value` | Get element at index |
| `getArrayString(path, index)`     | `?[]const u8`   | Get string at index  |
| `getArrayInt(path, index)`        | `?i64`          | Get integer at index |
| `getArrayBool(path, index)`       | `?bool`         | Get boolean at index |
| `appendToArray(path, string)`     | `!void`         | Append string        |
| `appendIntToArray(path, int)`     | `!void`         | Append integer       |
| `appendFloatToArray(path, float)` | `!void`         | Append float         |
| `appendBoolToArray(path, bool)`   | `!void`         | Append boolean       |

## Find & Replace

| Method                        | Return          | Description                  |
| ----------------------------- | --------------- | ---------------------------- |
| `findString(needle)`          | `![][]const u8` | Find paths containing needle |
| `findExact(needle)`           | `![][]const u8` | Find paths with exact match  |
| `replaceAll(find, replace)`   | `!usize`        | Replace all, returns count   |
| `replaceFirst(find, replace)` | `!bool`         | Replace first                |
| `replaceLast(find, replace)`  | `!bool`         | Replace last                 |

## Merge & Clone

| Method         | Return          | Description           |
| -------------- | --------------- | --------------------- |
| `merge(other)` | `!void`         | Merge other into this |
| `clone()`      | `!Document`     | Create deep copy      |
| `diff(other)`  | `![][]const u8` | Get differing keys    |

## Output

| Method                      | Return  | Description                                  |
| --------------------------- | ------- | -------------------------------------------- |
| `save()`                    | `!void` | Save to original path                        |
| `saveAs(path)`              | `!void` | Save to specified path                       |
| `saveAsAtomic(path)`        | `!void` | Atomically write file (write tmp + rename)   |
| `saveWithBackup(ext)`       | `!void` | Save and move previous file to `<path><ext>` |
| `saveIfChanged()`           | `!bool` | Save only if contents changed (returns true if written) |
| `toString()`                | `![]u8` | 4-space indent (caller frees)               |
| `toCompactString()`         | `![]u8` | No indentation                              |
| `toPrettyString(indent)`    | `![]u8` | Custom indentation                           |

## Object & Array Access

| Method            | Return           | Description          |
| ----------------- | ---------------- | -------------------- |
| `getObject(path)` | `?*Value.Object` | Get object reference |
| `getArray(path)`  | `?*Value.Array`  | Get array reference  |

## Cleanup

```zig
doc.deinit();
```

::: warning
Always call `deinit()` when done with a document to prevent memory leaks.
:::

## Complete Example

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

    // Set values
    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);

    // Nested paths
    try doc.setString("config.host", "localhost");
    try doc.setInt("config.timeout", 30);

    // Arrays
    try doc.setArray("paths");
    try doc.appendToArray("paths", "src");
    try doc.appendToArray("paths", "lib");

    // Read values
    const name = doc.getString("name").?;
    const port = doc.getInt("port").?;
    const path_count = doc.arrayLen("paths").?;

    std.debug.print("{s} on port {d}, {d} paths\n", .{name, port, path_count});

    // Check properties
    if (doc.exists("config.host")) {
        std.debug.print("Host: {s}\n", .{doc.getString("config.host").?});
    }

    if (doc.isEmpty()) {
        std.debug.print("Document is empty\n", .{});
    }

    // Find and replace
    const count = try doc.replaceAll("localhost", "production.example.com");
    std.debug.print("Replaced {d} values\n", .{count});

    // Clone
    var backup = try doc.clone();
    defer backup.deinit();

    // Output
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});

    // Save
    try doc.saveAs("config.zon");
}
```
