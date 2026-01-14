---
title: "Value Types"
description: "Value union and helper methods for ZON values: null, bool, number, string, identifier, object, and array."
---

# Value Types

The `Value` type represents all possible ZON data types.

## Type Definition

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

## Number Type

```zig
pub const Number = union(enum) {
    int: i128,
    float: f64,
};
```

## Value Methods

### Type Checking

| Method              | Return       | Description                     |
| ------------------- | ------------ | ------------------------------- |
| `isNull()`          | `bool`       | Check if value is null          |
| `isIdentifier()`    | `bool`       | Check if value is an identifier |
| `isNan()`           | `bool`       | Check if value is NaN           |
| `isPositiveInf()`   | `bool`       | Check if positive infinity      |
| `isNegativeInf()`   | `bool`       | Check if negative infinity      |
| `isSpecialFloat()`  | `bool`       | Check if NaN or Infinity        |
| `typeName()`        | `[]const u8` | Get precise type name           |
| `toBool()`          | `bool`       | Coerce value to boolean         |
| `hash()`            | `u64`        | **Stable content hash**         |
| `checksum(A, &out)` | `void`       | **Crypto checksum**             |
| `eql(Value)`        | `bool`       | **Deep equality check**         |

### Type Conversion

| Method           | Return        | Description                               |
| ---------------- | ------------- | ----------------------------------------- |
| `asString()`     | `?[]const u8` | Get as string (works for identifiers too) |
| `asIdentifier()` | `?[]const u8` | Get as identifier only                    |
| `asBool()`       | `?bool`       | Get as boolean                            |
| `asInt()`        | `?i64`        | Get as i64 (null if overflow)             |
| `asInt128()`     | `?i128`       | Get as i128 (all ZON integers)            |
| `asUint()`       | `?u64`        | Get as u64 (useful for fingerprints)      |
| `asFloat()`      | `?f64`        | Get as float (converts int to float)      |
| `asObject()`     | `?*Object`    | Get as object                             |
| `asArray()`      | `?*Array`     | Get as array                              |
| `to(alloc, T)`   | `!T`          | **Convert to Zig type**                   |
| `from(alloc, v)` | `!Value`      | **Create Value from Zig** (Static)        |

### Memory Management

| Method                 | Description               |
| ---------------------- | ------------------------- |
| Method                 | Description               |
| -------------------    | ------------------------- |
| `deinit(allocator)`    | Free all memory           |
| `clone(allocator)`     | Create deep copy          |
| `eql(other)`           | **Deep equality check**   |
| `toDebugString(alloc)` | Get debug representation  |

## Object Type

Key-value map with string keys.

```zig
pub const Object = struct {
    allocator: Allocator,
    entries: std.StringHashMapUnmanaged(Value),
};
```

### Object Methods

| Method            | Return          | Description                 |
| ----------------- | --------------- | --------------------------- |
| `init(allocator)` | `Object`        | Create empty object         |
| `deinit()`        | `void`          | Free all memory             |
| `get(key)`        | `?*Value`       | Get value by key            |
| `fetch(key)`      | `?*Value`       | Alias for get               |
| `at(key)`         | `?*Value`       | Alias for get               |
| `put(key, value)` | `!void`         | Set value                   |
| `set(key, value)` | `!void`         | Alias for put               |
| `insert(k, v)`    | `!void`         | Alias for put               |
| `remove(key)`     | `bool`          | Remove key                  |
| `delete(key)`     | `bool`          | Alias for remove            |
| `unset(key)`      | `bool`          | Alias for remove            |
| `count()`         | `usize`         | Number of keys              |
| `size()`          | `usize`         | Alias for count             |
| `len()`           | `usize`         | Alias for count             |
| `keys(allocator)` | `![][]const u8` | Get all keys (caller frees) |
| `clear()`         | `void`          | Remove all entries          |
| `reset()`         | `void`          | Alias for clear             |
| `empty()`         | `void`          | Alias for clear             |
| `iterator()`      | `Iterator`      | Get object iterator         |

## Array Type

Ordered list of values.

```zig
pub const Array = struct {
    allocator: Allocator,
    items: std.ArrayListUnmanaged(Value),
};
```

### Array Methods

| Method            | Return     | Description        |
| ----------------- | ---------- | ------------------ |
| `init(allocator)` | `Array`    | Create empty array |
| `deinit()`        | `void`     | Free all memory    |
| `append(value)`   | `!void`    | Add value          |
| `add(value)`      | `!void`    | Alias for append   |
| `push(value)`     | `!void`    | Alias for append   |
| `get(index)`      | `?*Value`  | Get value at index |
| `at(index)`       | `?*Value`  | Alias for get      |
| `len()`           | `usize`    | Number of elements |
| `size()`          | `usize`    | Alias for len      |
| `count()`         | `usize`    | Alias for len      |
| `clear()`         | `void`     | Remove all items   |
| `reset()`         | `void`     | Alias for clear    |
| `empty()`         | `void`     | Alias for clear    |
| `iterator()`      | `Iterator` | Get array iterator |
| `pop()`           | `?Value`   | **Remove last**    |
| `shift()`         | `?Value`   | **Remove first**   |
| `unshift(val)`    | `!void`    | **Ins start**      |

## Examples

### Creating Values

```zig
const allocator = std.heap.page_allocator;

// Null
var null_val: Value = .null_val;

// Boolean
var bool_val: Value = .{ .bool_val = true };

// Integer
var int_val: Value = .{ .number = .{ .int = 42 } };

// Float
var float_val: Value = .{ .number = .{ .float = 3.14 } };

// String (must be heap-allocated for proper cleanup)
const text = try allocator.dupe(u8, "hello");
var str_val: Value = .{ .string = text };
defer str_val.deinit(allocator);

// Identifier
const id = try allocator.dupe(u8, "my_package");
var id_val: Value = .{ .identifier = id };
defer id_val.deinit(allocator);
```

### Reading Values

```zig
const val: Value = .{ .number = .{ .int = 42 } };

// Safe access with optionals
if (val.asInt()) |i| {
    std.debug.print("Integer: {d}\n", .{i});
}

if (val.asString()) |s| {
    std.debug.print("String: {s}\n", .{s});
} else {
    std.debug.print("Not a string\n", .{});
}
```

### Working with Objects

```zig
const allocator = std.testing.allocator;

var obj = Value.Object.init(allocator);
defer obj.deinit();

// Add values
try obj.put("name", .{ .string = try allocator.dupe(u8, "test") });
try obj.put("enabled", .{ .bool_val = true });
try obj.put("count", .{ .number = .{ .int = 42 } });

// Read values
if (obj.get("name")) |val| {
    std.debug.print("Name: {s}\n", .{val.asString().?});
}

// Get all keys
const keys = try obj.keys(allocator);
defer allocator.free(keys);

for (keys) |key| {
    std.debug.print("Key: {s}\n", .{key});
}

// Remove
_ = obj.remove("count");
```

### Working with Arrays

```zig
const allocator = std.testing.allocator;

var arr = Value.Array.init(allocator);
defer arr.deinit();

// Add values
try arr.append(.{ .string = try allocator.dupe(u8, "first") });
try arr.append(.{ .string = try allocator.dupe(u8, "second") });
try arr.append(.{ .number = .{ .int = 3 } });

// Read values
for (0..arr.len()) |i| {
    if (arr.get(i)) |val| {
        if (val.asString()) |s| {
            std.debug.print("[{d}] String: {s}\n", .{i, s});
        } else if (val.asInt()) |n| {
            std.debug.print("[{d}] Int: {d}\n", .{i, n});
        }
    }
}
```

### Cloning Values

```zig
const allocator = std.testing.allocator;

var original: Value = .{ .string = try allocator.dupe(u8, "hello") };
defer original.deinit(allocator);

var cloned = try original.clone(allocator);
defer cloned.deinit(allocator);

// cloned is independent of original
try std.testing.expectEqualStrings("hello", cloned.asString().?);
```

## ZON Representation

| Value Type | ZON Syntax     | Example             |
| ---------- | -------------- | ------------------- |
| null       | `null`         | `null`              |
| bool       | `true`/`false` | `true`              |
| int        | number         | `42`, `0xFF`        |
| float      | number         | `3.14`              |
| string     | `"..."`        | `"hello"`           |
| identifier | `.name`        | `.my_package`       |
| object     | `.{ ... }`     | `.{ .key = value }` |
| array      | `.{ ... }`     | `.{ "a", "b" }`     |
