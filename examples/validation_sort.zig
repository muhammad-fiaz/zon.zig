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
