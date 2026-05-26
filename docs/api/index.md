---
title: "API Reference"
description: "Complete API reference for zon.zig: document creation, file utilities, update checking, version info, document methods, arrays, and more."
---

# API Overview

Complete API reference for zon.zig — a document-based ZON library.

::: tip Document vs Type-Based API
zon.zig provides a **document-based** (DOM-like) API where you work with a `Document` object containing a `Value` tree. This differs from Zig's [`std.zon`](https://codeberg.org/ziglang/zig/src/branch/master/lib/std/zon) which deserializes directly into typed Zig structures.

Use zon.zig when you need to edit, search, or manipulate ZON files dynamically.
:::

## Module Functions

Top-level functions exposed by the `zon` module.

### Document Creation

```zig
const zon = @import("zon");

// Create empty document (aliases: init, new)
var doc = zon.create(allocator);

// Open file (aliases: load, fromFile, parseFile)
var doc = try zon.open(allocator, "config.zon");

// Parse string (aliases: fromSource, parseString)
var doc = try zon.parse(allocator, source);

// Load or Create
var doc = try zon.loadOrCreate(allocator, "settings.zon", ".{}");

// From JSON (aliases: parseJson)
var doc = try zon.fromJson(allocator, json_string);

// From struct
var doc = try zon.fromStruct(allocator, my_struct);
```

### File Utilities

```zig
// Check if file exists (alias: hasFile)
if (zon.fileExists("config.zon")) { ... }

// Read file into allocator-owned buffer (caller frees)
const contents = try zon.readFile(allocator, "config.zon");
allocator.free(contents);

// Copy file (overwrite = true to replace destination)
try zon.copyFile("source.zon", "dest.zon", true);

// Move (rename) file (alias: renameFile, removeFile)
try zon.moveFile("old.zon", "new.zon", true);

// Delete file (alias: removeFile)
try zon.deleteFile("temp.zon");

// Key Operations (alias: movePathInFile, copyPathInFile)
try zon.movePathInFile(allocator, "config.zon", "old.key", "new.key");

// Write atomically (writes to temp and renames)
try zon.writeFileAtomic(allocator, "out.zon", sourceData);
```

### Validation & Encoding

```zig
// Validate ZON syntax
if (zon.validate(allocator, source)) { ... }
if (zon.validateFile(allocator, "config.zon")) { ... }

// Re-format ZON source
const formatted = try zon.format(allocator, source);
try zon.formatFile(allocator, "config.zon");

// Validate semantic version
if (zon.validateSemVer("1.2.3")) { ... }

// Base64 encode/decode
const enc = try zon.base64Encode(allocator, "hello");
const dec = try zon.base64Decode(allocator, enc);

// Stringify raw Value tree
const output = try zon.stringify(allocator, &value, .{});
const json = try zon.stringifyJson(allocator, &value);
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

| Method                | Return          | Description                     |
| --------------------- | --------------- | ------------------------------- |
| `getString(path)`     | `?[]const u8`   | Get string value                |
| `getStr(path)`        | `?[]const u8`   | Alias for getString             |
| `getIdentifier(path)` | `?[]const u8`   | Get identifier value            |
| `getBool(path)`       | `?bool`         | Get boolean value               |
| `getInt(path)`        | `?i64`          | Get integer value               |
| `getNum(path)`        | `?i64`          | Alias for getInt                |
| `getInteger(path)`    | `?i64`          | Alias for getInt                |
| `getInt128(path)`     | `?i128`         | Get full-precision integer      |
| `getUint(path)`       | `?u64`          | Get unsigned integer (u64)      |
| `getFloat(path)`      | `?f64`          | Get float value                 |
| `getDecimal(path)`    | `?f64`          | Alias for getFloat              |
| `getNumber(path)`     | `?f64`          | Alias for getFloat              |
| `getValue(path)`      | `?*const Value` | Get raw Value                   |

### Setters

| Method                         | Description                         |
| ------------------------------ | ----------------------------------- |
| `setString(path, value)`       | Set string value                    |
| `setStr(path, value)`          | Alias for setString                 |
| `putStr(path, value)`          | Alias for setString                 |
| `setIdentifier(path, value)`   | Set identifier (`.value`)           |
| `setBool(path, value)`         | Set boolean value                   |
| `setInt(path, value)`          | Set integer value                   |
| `putInt(path, value)`          | Alias for setInt                    |
| `setNum(path, value)`          | Alias for setInt                    |
| `setFloat(path, value)`        | Set float value                     |
| `setNumber(path, value)`       | Alias for setFloat                  |
| `setNull(path)`                | Set to null                         |
| `putNull(path)`                | Alias for setNull                   |
| `clearPath(path)`              | Alias for setNull                   |
| `setObject(path)`              | Create empty object                 |
| `setArray(path)`               | Create empty array                  |
| `setValue(path, value)`        | Set raw Value                       |
| `put(path, value)`             | Alias for setValue                  |
| `setFromStruct(path, value)`   | Set path from struct                |
| `getOrPutString(path, def)`    | Get or put string                   |
| `getOrPutInt(path, def)`       | Get or put integer                  |
| `getOrPutBool(path, def)`      | Get or put boolean                  |

### Checkers

| Method               | Return        | Description                       |
| -------------------- | ------------- | --------------------------------- |
| `exists(path)`       | `bool`        | Check if path exists              |
| `has(path)`          | `bool`        | Alias for exists                  |
| `contains(path)`     | `bool`        | Alias for exists                  |
| `isValue(path)`      | `bool`        | Alias for exists                  |
| `isKey(path)`        | `bool`        | Alias for exists                  |
| `isNull(path)`       | `bool`        | Check if value is null            |
| `isString(path)`     | `bool`        | Check if value is a string        |
| `isBool(path)`       | `bool`        | Check if value is a boolean       |
| `isInt(path)`        | `bool`        | Check if value is an integer      |
| `isFloat(path)`      | `bool`        | Check if value is a float         |
| `isNumber(path)`     | `bool`        | Check if value is int or float    |
| `isObject(path)`     | `bool`        | Check if value is an object       |
| `isArray(path)`      | `bool`        | Check if value is an array        |
| `isIdentifier(path)` | `bool`        | Check if value is identifier      |
| `isUpperCase(path)`  | `bool`        | Check if string is all uppercase  |
| `isLowerCase(path)`  | `bool`        | Check if string is all lowercase  |
| `isEmpty()`          | `bool`        | Check if document empty           |
| `getType(path)`      | `?[]const u8` | Get base type name                |
| `getTypeName(path)`  | `?[]const u8` | Get precise type name             |
| `isNan(path)`        | `bool`        | Check if value is NaN             |
| `isInf(path)`        | `bool`        | Check if value is Inf             |
| `toBool(path)`       | `bool`        | Coerce value to boolean           |
| `toInt(path, T)`     | `T`           | Coerce to integer type `T`        |
| `toUint(path, T)`    | `T`           | Coerce to unsigned type `T`       |
| `toFloat(path, T)`   | `T`           | Coerce to float type `T`          |
| `toString(path, T)`  | `!T`          | Convert to Zig struct             |

### Case Utilities

| Method                       | Return | Description                            |
| ---------------------------- | ------ | -------------------------------------- |
| `toUpper(path)`              | `!void`| Convert string to uppercase in-place   |
| `toLower(path)`              | `!void`| Convert string to lowercase in-place   |
| `isUpperCase(path)`          | `bool` | Check if string is all uppercase       |
| `isLowerCase(path)`          | `bool` | Check if string is all lowercase       |

### Modification

| Method                    | Return          | Description                 |
| ------------------------- | --------------- | --------------------------- |
| `delete(path)`            | `bool`          | Delete key                  |
| `remove(path)`            | `bool`          | Alias for delete            |
| `rename(old, new)`        | `!bool`         | Rename key/path             |
| `move(old, new)`          | `!bool`         | Alias for rename            |
| `copy(src, dst)`          | `!bool`         | Duplicate path              |
| `clear()`                 | `void`          | Clear all data              |
| `count()`                 | `usize`         | Number of root keys         |
| `size()`                  | `usize`         | Alias for count             |
| `len()`                   | `usize`         | Alias for count             |
| `keys()`                  | `![][]const u8` | Get all root keys           |
| `reload()`                | `!void`         | Reload from disk            |
| `hasChangedOnDisk()`      | `bool`          | Check if file modified      |
| `deleteFileOnDisk()`      | `!void`         | Delete associated file      |
| `renameFileOnDisk(new)`   | `!void`         | Rename associated file      |

### Array Operations

| Method                                  | Return          | Description                  |
| --------------------------------------- | --------------- | ---------------------------- |
| `arrayLen(path)`                        | `?usize`        | Get array length             |
| `getArrayElement(path, index)`          | `?*const Value` | Get element                  |
| `getArrayString(path, index)`           | `?[]const u8`   | Get string element           |
| `getArrayInt(path, index)`              | `?i64`          | Get integer element          |
| `getArrayBool(path, index)`             | `?bool`         | Get boolean element          |
| `appendToArray(path, string)`           | `!void`         | Append string                |
| `appendIntToArray(path, int)`           | `!void`         | Append integer               |
| `appendFloatToArray(path, float)`       | `!void`         | Append float                 |
| `appendBoolToArray(path, bool)`         | `!void`         | Append boolean               |
| `insertStringIntoArray(path, idx, val)` | `!void`         | Insert string at index       |
| `insertIntIntoArray(path, idx, val)`    | `!void`         | Insert integer at index      |
| `removeFromArray(path, index)`          | `bool`          | Remove item at index         |
| `popFromArray(path)`                    | `?Value`        | Pop last element             |
| `shiftArray(path)`                      | `?Value`        | Remove first element         |
| `unshiftArray(path, val)`               | `!void`         | Insert at start              |
| `indexOf(path, value)`                  | `?usize`        | Find string index            |
| `countAt(path)`                         | `usize`         | Count items at path          |
| `sortArray(path)`                       | `!void`         | Sort array ascending         |
| `reverseArray(path)`                    | `!void`         | Reverse array in-place       |
| `truncate(path, new_len)`               | `!void`         | Truncate to new length       |
| `dropFirst(path, n)`                    | `!void`         | Remove first n elements      |
| `dropLast(path, n)`                     | `!void`         | Remove last n elements       |
| `compact(path)`                         | `!void`         | Remove null values           |
| `unique(path)`                          | `!void`         | Remove duplicates            |
| `first(path)`                           | `?*const Value` | Get first element            |
| `last(path)`                            | `?*const Value` | Get last element             |
| `every(path, predicate)`                | `bool`          | Check all match predicate    |
| `some(path, predicate)`                 | `bool`          | Check any matches predicate  |

### Find & Replace

| Method                        | Return          | Description                    |
| ----------------------------- | --------------- | ------------------------------ |
| `findString(needle)`          | `![][]const u8` | Find paths containing value    |
| `findExact(needle)`           | `![][]const u8` | Find paths with exact value    |
| `findWhere(predicate)`        | `![][]const u8` | Find paths matching predicate  |
| `find(key)`                   | `?*Value`       | Recursive key search           |
| `findAll(key)`                | `![][]const u8` | Deep key search (paths)        |
| `replaceAll(find, replace)`   | `!usize`        | Replace all occurrences        |
| `replaceFirst(find, replace)` | `!bool`         | Replace first occurrence       |
| `replaceLast(find, replace)`  | `!bool`         | Replace last occurrence        |

### Merge & Clone

| Method                  | Return          | Description                   |
| ----------------------- | --------------- | ----------------------------- |
| `merge(other)`          | `!void`         | Shallow merge document        |
| `mergeRecursive(other)` | `!void`         | **Recursive (deep) merge**    |
| `clone()`               | `!Document`     | Create deep copy              |
| `eql(other)`            | `bool`          | **Deep equality check**       |
| `diff(other)`           | `![][]const u8` | Get differing keys            |
| `flatten()`             | `!Document`     | Convert to flat key-value map |

### Output

| Method                   | Return  | Description                       |
| ------------------------ | ------- | --------------------------------- |
| `toString()`             | `![]u8` | 4-space indent                    |
| `toCompactString()`      | `![]u8` | No indentation                    |
| `toPrettyString(indent)` | `![]u8` | Custom indentation                |
| `toJsonString()`         | `![]u8` | Serialize to JSON                 |
| `save()`                 | `!void` | Save to original path             |
| `saveAs(path)`           | `!void` | Save to new path                  |
| `saveAsAtomic(path)`     | `!void` | Atomically write to file          |
| `saveWithBackup(ext)`    | `!void` | Save with backup of previous file |
| `saveIfChanged()`        | `!bool` | Save only if contents differ      |

### Traversal & Transformation

| Method                        | Return        | Description                                   |
| ----------------------------- | ------------- | --------------------------------------------- |
| `paths()`                     | `![][]const u8` | Recursively list all paths in the document    |
| `walk(context, visitor)`      | `void`        | Depth-first traversal of all values           |
| `mapValues(context, mapper)`  | `!void`       | Transform all values recursively              |
| `forEach(context, callback)`  | `void`        | Iterate over all values with a callback       |
| `pick(paths)`                 | `!Document`   | New document with only specified paths        |
| `omit(paths)`                 | `!Document`   | New document excluding specified paths        |
| `filter(alloc, ctx, pred)`    | `!Document`   | New document with matching paths              |
| `sortKeys()`                  | `void`        | Recursively sort all object keys ascending    |
| `sortKeysDesc()`              | `void`        | Recursively sort all object keys descending   |

### Integrity & Size

| Method                   | Return   | Description                      |
| ------------------------ | -------- | -------------------------------- |
| `hash()`                 | `u64`    | Stable 64-bit content hash       |
| `checksum(algo, &out)`   | `void`   | Generate crypto digest           |
| `byteSize()`             | `!usize` | Size in bytes when formatted     |
| `compactSize()`          | `!usize` | Size in bytes when compact       |

### Object & Array Access

| Method             | Return           | Description           |
| ------------------ | ---------------- | --------------------- |
| `getObject(path)`  | `?*Value.Object` | Get mutable object    |
| `getArray(path)`   | `?*Value.Array`  | Get mutable array     |

### Cleanup

```zig
doc.deinit(); // Always call when done
doc.close();  // Alias for deinit
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

### Value Methods — Type Checking

| Method              | Return        | Description                     |
| ------------------- | ------------- | ------------------------------- |
| `isNull()`          | `bool`        | Check if null                   |
| `isString()`        | `bool`        | Check if string                 |
| `isBool()`          | `bool`        | Check if boolean                |
| `isInt()`           | `bool`        | Check if integer                |
| `isFloat()`         | `bool`        | Check if float                  |
| `isNumber()`        | `bool`        | Check if int or float           |
| `isObject()`        | `bool`        | Check if object                 |
| `isArray()`         | `bool`        | Check if array                  |
| `isIdentifier()`    | `bool`        | Check if identifier             |
| `isNan()`           | `bool`        | Check if NaN                    |
| `isPositiveInf()`   | `bool`        | Check if positive infinity      |
| `isNegativeInf()`   | `bool`        | Check if negative infinity      |
| `isSpecialFloat()`  | `bool`        | Check if NaN or Infinity        |
| `typeName()`        | `[]const u8`  | Get precise type name           |
| `toBool()`          | `bool`        | Coerce value to boolean         |
| `hash()`            | `u64`         | Stable content hash             |
| `checksum(A, &out)` | `void`        | Crypto checksum                 |
| `eql(Value)`        | `bool`        | Deep equality check             |

### Value Methods — Type Conversion

| Method              | Return        | Description                         |
| ------------------- | ------------- | ----------------------------------- |
| `asString()`        | `?[]const u8` | Get as string (works for identifiers) |
| `asIdentifier()`    | `?[]const u8` | Get as identifier only              |
| `asBool()`          | `?bool`       | Get as boolean                      |
| `asInt()`           | `?i64`        | Get as i64 (null if overflow)       |
| `asInt128()`        | `?i128`       | Get as i128 (all ZON integers)      |
| `asUint()`          | `?u64`        | Get as u64 (useful for fingerprints)|
| `asFloat()`         | `?f64`        | Get as float (converts int to float)|
| `asObject()`        | `?*Object`    | Get as object                       |
| `asArray()`         | `?*Array`     | Get as array                        |
| `to(alloc, T)`      | `!T`          | Convert to Zig type                 |
| `from(alloc, v)`    | `!Value`      | Create Value from Zig               |
| `clone(allocator)`  | `!Value`      | Deep copy                           |
| `toDebugString(alloc)` | `![]u8`    | Get debug representation            |
| `deinit(allocator)` | `void`        | Free memory                         |

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

    // Set various types
    try doc.setIdentifier("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setBool("debug", true);
    try doc.setFloat("rate", 0.05);
    try doc.setNull("password");

    // Nested paths
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

    // Type-check nested values
    if (doc.isString("db.host") and doc.isInt("db.port")) {
        std.debug.print("Database configured\n", .{});
    }

    // Validate and check nested identifiers
    if (doc.isIdentifier("name")) {
        std.debug.print("Package: .{s}\n", .{doc.getIdentifier("name").?});
    }

    // Case utilities
    try doc.toUpper("version"); // "1.0.0" -> "1.0.0" (no-op)
    if (doc.isLowerCase("name")) {
        try doc.toUpper("name"); // "myapp" -> "MYAPP"
    }

    // Modify
    _ = doc.delete("debug");

    // Clone
    var backup = try doc.clone();
    defer backup.deinit();

    // Validate semver and encode
    if (zon.validateSemVer("1.2.3")) {
        const enc = try zon.base64Encode(allocator, "hello");
        defer allocator.free(enc);
    }

    // Output
    const output = try doc.toString();
    defer allocator.free(output);

    // Save
    try doc.saveAs("config.zon");
}
```
