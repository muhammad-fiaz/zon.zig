---
title: "Validation and Sort Example"
description: "Type checking, case utilities, array sorting, truncation, and predicate filtering."
---

# Validation & Sort Example

**Usecase:** validate shapes at runtime — type checks (`isString`, `isInt`,
`isFloat`, `isNumber`, `isBool`, `isArray`, `isObject`, `isValue`, `isKey`),
case conversion (`toUpper`, `toLower`, `isUpperCase`, `isLowerCase`), array
sorting/truncation, descending key sort, and predicate `filter`.

**Run:** `zig build run-validation_sort`

```zig
const std = @import("std");
const zon = @import("zon");

/// Example: Type checking, case utilities, sorting, array truncation
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Type Checking ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "MyApp");
    try doc.setInt("port", 8080);
    try doc.setFloat("rate", 1.5);
    try doc.setBool("enabled", true);
    try doc.setArray("tags");
    try doc.setObject("nested");

    std.debug.print("isString(\"name\"):    {}\n", .{doc.isString("name")});
    std.debug.print("isInt(\"port\"):       {}\n", .{doc.isInt("port")});
    std.debug.print("isFloat(\"rate\"):     {}\n", .{doc.isFloat("rate")});
    std.debug.print("isNumber(\"port\"):    {}\n", .{doc.isNumber("port")});
    std.debug.print("isNumber(\"rate\"):    {}\n", .{doc.isNumber("rate")});
    std.debug.print("isBool(\"enabled\"):   {}\n", .{doc.isBool("enabled")});
    std.debug.print("isArray(\"tags\"):     {}\n", .{doc.isArray("tags")});
    std.debug.print("isObject(\"nested\"):  {}\n", .{doc.isObject("nested")});
    std.debug.print("isValue(\"name\"):     {}\n", .{doc.isValue("name")});
    std.debug.print("isKey(\"name\"):       {}\n\n", .{doc.isKey("name")});

    std.debug.print("=== Case Utilities ===\n\n", .{});

    std.debug.print("Original: \"{s}\"\n", .{doc.getString("name").?});
    try doc.toUpper("name");
    std.debug.print("toUpper:  \"{s}\"\n", .{doc.getString("name").?});
    std.debug.print("isUpperCase: {}\n", .{doc.isUpperCase("name")});
    try doc.toLower("name");
    std.debug.print("toLower:  \"{s}\"\n", .{doc.getString("name").?});
    std.debug.print("isLowerCase: {}\n\n", .{doc.isLowerCase("name")});

    std.debug.print("=== Array Sorting and Truncation ===\n\n", .{});

    try doc.appendToArray("tags", "zig");
    try doc.appendToArray("tags", "apple");
    try doc.appendToArray("tags", "rust");
    try doc.appendToArray("tags", "beta");
    try doc.appendToArray("tags", "gamma");

    try doc.sortArray("tags");
    std.debug.print("sortArray: ", .{});
    if (doc.arrayLen("tags")) |len| {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            std.debug.print("\"{s}\" ", .{doc.getArrayString("tags", i).?});
        }
    }
    std.debug.print("\n", .{});

    try doc.reverseArray("tags");
    std.debug.print("reverseArray: ", .{});
    if (doc.arrayLen("tags")) |len| {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            std.debug.print("\"{s}\" ", .{doc.getArrayString("tags", i).?});
        }
    }
    std.debug.print("\n", .{});

    try doc.dropFirst("tags", 2);
    std.debug.print("dropFirst(2): ", .{});
    if (doc.arrayLen("tags")) |len| {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            std.debug.print("\"{s}\" ", .{doc.getArrayString("tags", i).?});
        }
    }
    std.debug.print("\n", .{});

    try doc.dropLast("tags", 1);
    std.debug.print("dropLast(1):  ", .{});
    if (doc.arrayLen("tags")) |len| {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            std.debug.print("\"{s}\" ", .{doc.getArrayString("tags", i).?});
        }
    }
    std.debug.print("\n\n", .{});

    std.debug.print("=== sortKeysDesc ===\n\n", .{});

    var obj = zon.Value.Object.init(allocator);
    try obj.put("z", .{ .string = try allocator.dupe(u8, "last") });
    try obj.put("a", .{ .string = try allocator.dupe(u8, "first") });
    try obj.put("m", .{ .string = try allocator.dupe(u8, "middle") });

    var descDoc = zon.Document{ .allocator = allocator, .root = .{ .object = obj }, .filePath = null };
    defer descDoc.deinit();

    descDoc.sortKeysDesc();
    const descStr = try descDoc.toString();
    defer allocator.free(descStr);
    std.debug.print("{s}\n\n", .{descStr});

    std.debug.print("=== filter ===\n\n", .{});

    var filterDoc = zon.create(allocator);
    defer filterDoc.deinit();
    try filterDoc.setString("name", "test");
    try filterDoc.setInt("version", 1);
    try filterDoc.setBool("active", true);

    const Ctx = struct {
        fn isString(_: *@This(), _: []const u8, value: *const zon.Value) bool {
            return value.* == .string;
        }
    };

    var ctx = Ctx{};
    var filtered = try filterDoc.filter(&ctx, Ctx.isString);
    defer filtered.deinit();

    std.debug.print("Filtered (only strings):\n", .{});
    const filteredStr = try filtered.toPrettyString(2);
    defer allocator.free(filteredStr);
    std.debug.print("{s}\n", .{filteredStr});
}
```

```bash
=== Type Checking ===

isString("name"):    true
isInt("port"):       true
isFloat("rate"):     true
isNumber("port"):    true
isNumber("rate"):    true
isBool("enabled"):   true
isArray("tags"):     true
isObject("nested"):  true
isValue("name"):     true
isKey("name"):       true

=== Case Utilities ===

Original: "MyApp"
toUpper:  "MYAPP"
isUpperCase: true
toLower:  "myapp"
isLowerCase: true

=== Array Sorting and Truncation ===

sortArray: "apple" "beta" "gamma" "rust" "zig"
reverseArray: "zig" "rust" "gamma" "beta" "apple"
dropFirst(2): "gamma" "beta" "apple"
dropLast(1):  "gamma" "beta"

=== sortKeysDesc ===

.{
    .a = "first",
    .m = "middle",
    .z = "last",
}

=== filter ===

Filtered (only strings):
.{
  .name = "test",
}
```
