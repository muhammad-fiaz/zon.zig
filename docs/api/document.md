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

### Init From Struct

```zig
const Config = struct { name: []const u8, port: u16 };
var doc = try zon.initFromStruct(allocator, Config{ .name = "app", .port = 80 });
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
| `isString(path)`      | `bool`          | Check if value is string     |
| `isBool(path)`        | `bool`          | Check if value is bool       |
| `isInt(path)`         | `bool`          | Check if value is integer    |
| `isFloat(path)`       | `bool`          | Check if value is float      |
| `isNumber(path)`      | `bool`          | Check if value is a number   |
| `isObject(path)`      | `bool`          | Check if value is an object  |
| `isArray(path)`       | `bool`          | Check if value is an array   |
| `isValue(path)`       | `bool`          | Alias for exists             |
| `isKey(path)`         | `bool`          | Alias for exists             |
| `exists(path)`        | `bool`          | Check if path exists         |
| `has(path)`           | `bool`          | Alias for exists             |
| `contains(path)`      | `bool`          | Alias for exists             |
| `getType(path)`       | `?[]const u8`   | Get base type name           |
| `getTypeName(path)`   | `?[]const u8`   | Get precise type name        |
| `isNan(path)`         | `bool`          | Check if value is NaN        |
| `isInf(path)`         | `bool`          | Check if value is Inf        |
| `getUint(path)`       | `?u64`          | Get unsigned integer (u64)   |
| `getInt128(path)`     | `?i128`         | Get full-precision integer   |
| `toBool(path)`        | `bool`          | Coerce value to boolean      |
| `toInt(path, T)`      | `T`             | Coerce to integer type `T`   |
| `toUint(path, T)`     | `T`             | Coerce to unsigned type `T`  |
| `toFloat(path, T)`    | `T`             | Coerce to float type `T`     |
| `toStruct(T)`         | `!T`            | **Convert to Zig struct**    |
    
## Case Utilities

| Method                       | Return | Description                            |
| ---------------------------- | ------ | -------------------------------------- |
| `toUpper(path)`              | `!void`| Convert string to uppercase in-place   |
| `toLower(path)`              | `!void`| Convert string to lowercase in-place   |
| `isUpperCase(path)`          | `bool` | Check if string is all uppercase       |
| `isLowerCase(path)`          | `bool` | Check if string is all lowercase       |

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
| `getOrPutString(p, d)` | Get or put string         |
| `getOrPutInt(p, d)`    | Get or put integer        |
| `getOrPutBool(p, d)`   | Get or put boolean        |
| `setFromStruct(p, v)`  | **Set path from struct**  |

## Modification

| Method         | Return          | Description                         |
| -------------- | --------------- | ----------------------------------- |
| `delete(path)` | `bool`          | Delete key, returns true if existed |
| `remove(path)` | `bool`          | Alias for delete                    |
| `rename(o, n)` | `!bool`         | Rename key/path                     |
| `move(o, n)`   | `!bool`         | Alias for rename                    |
| `copy(s, d)`            | `!bool`         | Duplicate path                      |
| `reload()`              | `!void`         | **Reload from disk**                |
| `hasChangedOnDisk()`    | `bool`          | **Check if file modified**          |
| `deleteFileOnDisk()`    | `!void`         | **Delete associated file**          |
| `renameFileOnDisk(new)` | `!void`         | **Rename associated file**          |
| `clear()`               | `void`          | Clear all data                      |
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
| `countAt(path)`                         | `usize`         | Count items at path    |
| `popFromArray(path)`                    | `?Value`        | **Pop last element**   |
| `shiftArray(path)`                      | `?Value`        | **Remove first**       |
| `unshiftArray(path, val)`               | `!void`         | **Ins at start**       |
| `sortArray(path)`                       | `!void`         | Sort array ascending   |
| `reverseArray(path)`                    | `!void`         | Reverse array in-place |
| `truncate(path, new_len)`               | `!void`         | Truncate to new length |
| `dropFirst(path, n)`                    | `!void`         | Remove first n elements|
| `dropLast(path, n)`                     | `!void`         | Remove last n elements |
| `compact(path)`                         | `!void`         | Remove null values     |
| `unique(path)`                          | `!void`         | Remove duplicates      |
| `first(path)`                           | `?*const Value` | Get first element      |
| `last(path)`                            | `?*const Value` | Get last element       |
| `every(path, predicate)`                | `bool`          | Check all match predicate |
| `some(path, predicate)`                 | `bool`          | Check any matches predicate |

## Find & Replace

| Method                        | Return          | Description                  |
| ----------------------------- | --------------- | ---------------------------- |
| `findString(needle)`          | `![][]const u8` | Find paths containing needle |
| `findExact(needle)`           | `![][]const u8` | Find paths with exact match  |
| `findWhere(predicate)`        | `![][]const u8` | **Find paths matching predicate** |
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

## Traversal & Transformation

| Method                                     | Return        | Description                                     |
| ------------------------------------------ | ------------- | ----------------------------------------------- |
| `paths()`                                  | `![][]const u8` | Recursively list all paths in the document      |
| `walk(context, visitor)`                   | `void`        | Depth-first traversal of all values             |
| `mapValues(context, mapper)`               | `!void`       | Transform all values recursively                |
| `pick(paths)`                              | `!Document`   | Create new document with only specified paths    |
| `omit(paths)`                              | `!Document`   | Create new document excluding specified paths    |
| `sortKeys()`                               | `void`        | Recursively sort all object keys alphabetically      |
| `sortKeysDesc()`                           | `void`        | Recursively sort all object keys in descending order |
| `filter(alloc, ctx, predicate)`            | `!Document`   | Create new document with matching paths              |
| `forEach(ctx, callback)`                   | `void`        | Iterate over all values with a callback              |

### `paths()`

Returns all paths (dot notation) in the document, including intermediate objects and array indices.

```zig
const all_paths = try doc.paths();
defer {
    for (all_paths) |p| allocator.free(p);
    allocator.free(all_paths);
}
```

### `walk()`

Depth-first traversal of all values. The `visitor` callback receives `(context, path, *const Value)`.

```zig
const Ctx = struct { count: usize };
var ctx = Ctx{ .count = 0 };
doc.walk(&ctx, struct {
    fn visit(c: *Ctx, path: []const u8, _: *const zon.Value) void {
        std.debug.print("[{d}] {s}\n", .{ c.count, path });
        c.count += 1;
    }
}.visit);
```

### `mapValues()`

Recursively transforms all leaf values. The `mapper` callback receives an owned `Value` and must return a new `Value`. The callback must free the old value when returning a new one.

```zig
const Ctx = struct {
    allocator: std.mem.Allocator,
    fn upper(c: *@This(), _: []const u8, value: zon.Value) anyerror!zon.Value {
        if (value == .string) {
            var owned = value;
            const result = try std.ascii.allocUpperString(c.allocator, owned.string);
            owned.deinit(c.allocator);
            return zon.Value{ .string = result };
        }
        return value;
    }
};
var ctx = Ctx{ .allocator = allocator };
try doc.mapValues(&ctx, Ctx.upper);
```

### `pick()`

Creates a new document containing only the specified paths. Nested paths preserve their intermediate structure.

```zig
var picked = try doc.pick(&.{ "name", "version" });
defer picked.deinit();
```

### `omit()`

Creates a new document excluding the specified paths.

```zig
var omitted = try doc.omit(&.{ "private" });
defer omitted.deinit();
```

### `sortKeys()`

Recursively sorts all object keys in the document in alphabetical order. Operates in-place on the document tree.

```zig
doc.sortKeys();
```

### `sortKeysDesc()`

Recursively sorts all object keys in descending alphabetical order.

```zig
doc.sortKeysDesc();
```

### `sortArray()`

Sorts array elements at a path in ascending order (string comparison).

```zig
try doc.sortArray("tags");
```

### `reverseArray()`

Reverses array elements in-place.

```zig
try doc.reverseArray("tags");
```

### `truncate()`, `dropFirst()`, `dropLast()`

Shorten or trim arrays:

```zig
try doc.truncate("arr", 2);     // keep only first 2 elements
try doc.dropFirst("arr", 1);    // remove first element
try doc.dropLast("arr", 2);     // remove last 2 elements
```

### `compact()` and `unique()`

Clean up arrays:

```zig
try doc.compact("arr");  // remove all null values
try doc.unique("arr");   // remove duplicate values
```

### `first()` and `last()`

Access array boundaries:

```zig
if (doc.first("arr")) |first| { /* ... */ }
if (doc.last("arr")) |last| { /* ... */ }
```

### `filter()`

Creates a new document containing only paths where a predicate returns true. The predicate receives each path and value.

```zig
const Ctx = struct {
    fn isString(_: *@This(), _: []const u8, value: *const zon.Value) bool {
        return value.* == .string;
    }
};
var ctx = Ctx{};
var filtered = try doc.filter(allocator, &ctx, Ctx.isString);
defer filtered.deinit();
```

### `forEach()`

Iterates over all values with a callback. Alias for `walk()`.

```zig
var count: usize = 0;
const Ctx = struct { count: *usize };
var ctx = Ctx{ .count = &count };
doc.forEach(&ctx, struct {
    fn cb(c: *Ctx, _: []const u8, _: *const zon.Value) void {
        c.count.* += 1;
    }
}.cb);
```

### `every()` and `some()`

Check array element conditions:

```zig
fn isEven(v: *const zon.Value) bool {
    return v.asInt().? % 2 == 0;
}
const all_even = doc.every("nums", isEven);
const any_odd = doc.some("nums", isOdd);
```

## Validating Nested Values

All type-checking methods (`isString`, `isBool`, `isInt`, `isFloat`, `isNumber`, `isObject`, `isArray`, `isNull`, `isIdentifier`) and existence checks (`exists`, `has`, `contains`, `isValue`, `isKey`) support **dot-separated nested paths**. Use them to validate the shape of deeply nested documents without manually traversing.

```zig
const source =
    \\.{
    \\    .server = .{
    \\        .host = "localhost",
    \\        .port = 8080,
    \\        .ssl = .{ .enabled = true },
    \\        .rate = 3.14,
    \\    },
    \\    .tags = .{ "a", "b", "c" },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Validate nested structure
if (doc.isString("server.host")) {
    std.debug.print("host is a string\n", .{});
}
if (doc.isInt("server.port")) {
    std.debug.print("port is an integer\n", .{});
}
if (doc.isBool("server.ssl.enabled")) {
    std.debug.print("ssl.enabled is a bool\n", .{});
}
if (doc.isFloat("server.rate")) {
    std.debug.print("rate is a float\n", .{});
}
if (doc.isArray("tags")) {
    std.debug.print("tags is an array ({d} items)\n", .{doc.arrayLen("tags").?});
}

// Quick existence checks on deep paths
if (doc.exists("server.ssl.enabled")) {
    const enabled = doc.getBool("server.ssl.enabled").?;
    // ...
}
```

## Identifiers

ZON identifiers (`.name = .my_package`) represent enum-like symbols. zon.zig stores them as strings (without the leading dot) and provides dedicated accessors.

### Setting Identifiers

```zig
try doc.setIdentifier("name", "my_package");
// Output: .{ .name = .my_package }
```

### Reading Identifiers

```zig
// Get as identifier (returns null if not an identifier)
if (doc.getIdentifier("name")) |id| {
    std.debug.print("Package: .{s}\n", .{id});
}

// getString also works for identifiers
const as_str = doc.getString("name").?; // "my_package"

// Check without reading
if (doc.isIdentifier("name")) {
    std.debug.print("'name' is an identifier\n", .{});
}
```

### Nested Identifiers

Dot-path access works for identifiers too:

```zig
// .{ .dependencies = .{ .http = .{ .version = .v1_0 } } }
try doc.setIdentifier("dependencies.http.version", "v1_0");

if (doc.isIdentifier("dependencies.http.version")) {
    const ver = doc.getIdentifier("dependencies.http.version").?;
    std.debug.print("Version: .{s}\n", .{ver});
}
```

### Case Utilities on Identifiers

```zig
try doc.setIdentifier("mode", "production");
try doc.toUpper("mode"); // stored as "PRODUCTION"
try doc.toLower("mode"); // stored as "production"
```

## findWhere

Search for paths where a value satisfies a custom predicate:

```zig
fn isLargeInt(v: *const zon.Value) bool {
    return v.isInt() and v.asInt().? > 100;
}

const matches = try doc.findWhere(isLargeInt);
defer {
    for (matches) |m| allocator.free(m);
    allocator.free(matches);
}
std.debug.print("Found {d} large integers\n", .{matches.len});
```

## Output

| Method                   | Return  | Description                                             |
| ------------------------ | ------- | ------------------------------------------------------- |
| `save()`                 | `!void` | Save to original path                                   |
| `saveAs(path)`           | `!void` | Save to specified path                                  |
| `saveAsAtomic(path)`     | `!void` | Atomically write file (write tmp + rename)              |
| `saveWithBackup(ext)`    | `!void` | Save and move previous file to `<path><ext>`            |
| `saveIfChanged()`        | `!bool` | Save only if contents changed (returns true if written) |
| `toString()`             | `![]u8` | 4-space indent (caller frees)                           |
| `toJsonString()`         | `![]u8` | Serialize to JSON                                        |
| `toStruct(T)`            | `!T`    | **Convert to Zig struct**                               |
| `toCompactString()`      | `![]u8` | No indentation                                          |
| `toPrettyString(indent)` | `![]u8` | Custom indentation                                      |

## Utilities (Top-level)

| Method                    | Return    | Description                      |
| ------------------------- | --------- | -------------------------------- |
| `zon.validate(src)`       | `bool`    | Check if ZON is valid            |
| `zon.validateFile(path)`  | `bool`    | Check if file is valid ZON       |
| `zon.validateSemVer(str)` | `bool`    | Check if string is valid semver  |
| `zon.base64Encode(alloc, data)` | `![]const u8` | Encode bytes to base64      |
| `zon.base64Decode(alloc, str)`  | `![]u8`       | Decode base64 string        |
| `zon.format(src)`         | `![]u8`   | Re-format ZON source             |
| `zon.formatFile(path)`    | `!void`   | Re-format ZON file in-place      |
| `zon.deleteFile(path)`    | `!void`   | Delete a file                    |
| `zon.removeFile(path)`    | `!void`   | Alias for deleteFile             |
| `zon.copyFile(src,dst)`   | `!void`   | Copy a file                      |
| `zon.moveFile(old,new)`   | `!void`   | Rename/Move a file               |
| `zon.renameFile(old,new)` | `!void`   | Alias for moveFile               |
| `zon.movePathInFile()`    | `!void`   | Move key inside ZON file         |
| `zon.copyPathInFile()`    | `!void`   | Copy key inside ZON file         |
| `zon.isZonValid(src)`     | `bool`    | Alias for validate               |
| `zon.isZonFileValid(p)`   | `bool`    | Alias for validateFile           |

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
