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

### Load or Create

```zig
var doc = try zon.loadOrCreate(allocator, "settings.zon", ".{ .theme = .dark }");
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
| `getStr(path)`        | `?[]const u8`   | Alias for getString          |
| `getIdentifier(path)` | `?[]const u8`   | Get identifier value         |
| `getBool(path)`       | `?bool`         | Get boolean value            |
| `getInt(path)`        | `?i64`          | Get integer value            |
| `getNum(path)`        | `?i64`          | Alias for getInt             |
| `getInteger(path)`    | `?i64`          | Alias for getInt             |
| `getFloat(path)`      | `?f64`          | Get float value              |
| `getDecimal(path)`    | `?f64`          | Alias for getFloat           |
| `getNumber(path)`     | `?f64`          | Alias for getFloat           |
| `getValue(path)`      | `?*const Value` | Get raw Value                |
| `isNull(path)`        | `bool`          | Check if value is null       |
| `isIdentifier(path)`  | `bool`          | Check if value is identifier |
| `exists(path)`        | `bool`          | Check if path exists         |
| `has(path)`           | `bool`          | Alias for exists             |
| `contains(path)`      | `bool`          | Alias for exists             |
| `getType(path)`       | `?[]const u8`   | Get base type name           |
| `getTypeName(path)`   | `?[]const u8`   | Get precise type name        |
| `isNan(path)`         | `bool`          | Check if value is NaN        |
| `isInf(path)`         | `bool`          | Check if value is Inf        |
| `getUint(path)`       | `?u64`          | Get unsigned integer (u64)   |
| `toBool(path)`        | `bool`          | Coerce value to boolean      |

## Setters

All setters auto-create intermediate objects.

| Method                 | Description               |
| ---------------------- | ------------------------- |
| `setString(path, val)` | Set string value          |
| `setStr(path, val)`    | Alias for setString       |
| `putStr(path, val)`    | Alias for setString       |
| `setIdentifier(p, v)`  | Set identifier (`.value`) |
| `setBool(p, v)`        | Set boolean value         |
| `setInt(p, v)`         | Set integer value         |
| `putInt(p, v)`         | Alias for setInt          |
| `setNum(p, v)`         | Alias for setInt          |
| `setFloat(p, v)`       | Set float value           |
| `setNumber(p, v)`      | Alias for setFloat        |
| `setNull(path)`        | Set value to null         |
| `putNull(path)`        | Alias for setNull         |
| `clearPath(path)`      | Alias for setNull         |
| `setObject(path)`      | Create empty object       |
| `setArray(path)`       | Create empty array        |
| `setValue(path, v)`    | Set raw Value             |
| `put(path, v)`         | Alias for setValue        |

## Modification

| Method         | Return          | Description                         |
| -------------- | --------------- | ----------------------------------- |
| `delete(path)` | `bool`          | Delete key, returns true if existed |
| `remove(path)` | `bool`          | Alias for delete                    |
| `rename(o, n)` | `!bool`         | Rename key/path                     |
| `move(o, n)`   | `!bool`         | Alias for rename                    |
| `copy(s, d)`   | `!bool`         | Duplicate path                      |
| `clear()`      | `void`          | Clear all data                      |
| `count()`      | `usize`         | Number of root keys                 |
| `size()`       | `usize`         | Alias for count                     |
| `len()`        | `usize`         | Alias for count                     |
| `keys()`       | `![][]const u8` | All root keys (caller frees)        |
| `isEmpty()`    | `bool`          | Check if document is empty          |

## Array Operations

| Method                                  | Return          | Description          |
| --------------------------------------- | --------------- | -------------------- |
| `arrayLen(path)`                        | `?usize`        | Get array length     |
| `getArrayElement(path, index)`          | `?*const Value` | Get element at index |
| `getArrayString(path, index)`           | `?[]const u8`   | Get string at index  |
| `getArrayInt(path, index)`              | `?i64`          | Get integer at index |
| `getArrayBool(path, index)`             | `?bool`         | Get boolean at index |
| `appendToArray(path, string)`           | `!void`         | Append string        |
| `appendIntToArray(path, int)`           | `!void`         | Append integer       |
| `appendFloatToArray(path, float)`       | `!void`         | Append float         |
| `appendBoolToArray(path, bool)`         | `!void`         | Append boolean       |
| `removeFromArray(path, index)`          | `bool`          | Remove item at index |
| `insertStringIntoArray(path, idx, val)` | `!void`         | Insert string        |
| `insertIntIntoArray(path, idx, val)`    | `!void`         | Insert integer       |
| `indexOf(path, value)`                  | `?usize`        | Find string index    |
| `countAt(path)`                         | `usize`         | Count items at path  |

## Find & Replace

| Method                        | Return          | Description                  |
| ----------------------------- | --------------- | ---------------------------- |
| `findString(needle)`          | `![][]const u8` | Find paths containing needle |
| `findExact(needle)`           | `![][]const u8` | Find paths with exact match  |
| `replaceAll(find, replace)`   | `!usize`        | Replace all, returns count   |
| `replaceFirst(find, replace)` | `!bool`         | Replace first                |
| `replaceLast(find, replace)`  | `!bool`         | Replace last                 |
| `find(key)`                   | `?*Value`       | **Recursive key search**     |
| `findAll(key)`                | `![][]const u8` | **Deep key search (paths)**  |
| `rename(old, new)`            | `!bool`         | Rename key/path              |
| `move(old, new)`              | `!bool`         | Alias for rename             |
| `copy(src, dst)`              | `!bool`         | Duplicate path               |
| `diff(other)`                 | `![]const []u8` | **Deep recursive diff**      |
| `flatten()`                   | `!Document`     | **Convert to flat map**      |

## Integrity & Size

| Method                 | Return   | Description                  |
| ---------------------- | -------- | ---------------------------- |
| `hash()`               | `u64`    | Stable 64-bit content hash   |
| `checksum(algo, &out)` | `void`   | Generate crypto digest       |
| `byteSize()`           | `!usize` | Size in bytes when formatted |
| `compactSize()`        | `!usize` | Size in bytes when compact   |

## Merge & Clone

| Method                  | Return      | Description                |
| ----------------------- | ----------- | -------------------------- |
| `merge(other)`          | `!void`     | Shallow merge document     |
| `mergeRecursive(other)` | `!void`     | **Recursive (deep) merge** |
| `clone()`               | `!Document` | Create deep copy           |
| `eql(other)`            | `bool`      | **Deep equality check**    |

## Convenience Methods

| Method                       | Return        | Description             |
| ---------------------------- | ------------- | ----------------------- |
| `getStringOr(path, default)` | `[]const u8`  | Get string or fallback  |
| `getIntOr(path, default)`    | `i64`         | Get integer or fallback |
| `getBoolOr(path, default)`   | `bool`        | Get boolean or fallback |
| `getFloatOr(path, default)`  | `f64`         | Get float or fallback   |
| `getTypeName(path)`          | `?[]const u8` | Get precise type name   |

## Output

| Method                   | Return  | Description                                             |
| ------------------------ | ------- | ------------------------------------------------------- |
| `save()`                 | `!void` | Save to original path                                   |
| `saveAs(path)`           | `!void` | Save to specified path                                  |
| `saveAsAtomic(path)`     | `!void` | Atomically write file (write tmp + rename)              |
| `saveWithBackup(ext)`    | `!void` | Save and move previous file to `<path><ext>`            |
| `saveIfChanged()`        | `!bool` | Save only if contents changed (returns true if written) |
| `toString()`             | `![]u8` | 4-space indent (caller frees)                           |
| `toCompactString()`      | `![]u8` | No indentation                                          |
| `toPrettyString(indent)` | `![]u8` | Custom indentation                                      |

## Utilities (Top-level)

| Method                    | Return  | Description                 |
| ------------------------- | ------- | --------------------------- |
| `zon.validate(src)`       | `bool`  | Check if ZON is valid       |
| `zon.validateFile(path)`  | `bool`  | Check if file is valid ZON  |
| `zon.format(src)`         | `![]u8` | Re-format ZON source        |
| `zon.formatFile(path)`    | `!void` | Re-format ZON file in-place |
| `zon.deleteFile(path)`    | `!void` | Delete a file               |
| `zon.removeFile(path)`    | `!void` | Alias for deleteFile        |
| `zon.copyFile(src,dst)`   | `!void` | Copy a file                 |
| `zon.moveFile(old,new)`   | `!void` | Rename/Move a file          |
| `zon.renameFile(old,new)` | `!void` | Alias for moveFile          |
| `zon.movePathInFile()`    | `!void` | Move key inside ZON file    |
| `zon.copyPathInFile()`    | `!void` | Copy key inside ZON file    |
| `zon.isZonValid(src)`     | `bool`  | Alias for validate          |
| `zon.isZonFileValid(p)`   | `bool`  | Alias for validateFile      |

## Object & Array Access

| Method            | Return           | Description          |
| ----------------- | ---------------- | -------------------- |
| `getObject(path)` | `?*Value.Object` | Get object reference |
| `getArray(path)`  | `?*Value.Array`  | Get array reference  |

## Cleanup

```zig
doc.close();
// or
doc.deinit();
```

::: warning Resource Management
Always call `close()` or `deinit()` when done with a document to prevent memory leaks.
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
