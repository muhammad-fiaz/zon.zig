# Basic Usage

Core operations for working with ZON documents.

## Creating a Document

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var doc = zon.create(allocator);
    defer doc.deinit(); // Always clean up
}
```

## Setting Values

### String Values

```zig
try doc.setString("name", "myapp");
try doc.setString("version", "1.0.0");
```

**Output:**

```zig
.{
    .name = "myapp",
    .version = "1.0.0",
}
```

### Identifier Values

Use `setIdentifier` for `.name = .value` syntax:

```zig
try doc.setIdentifier("name", "my_package");
```

**Output:**

```zig
.{
    .name = .my_package,
}
```

### Boolean Values

```zig
try doc.setBool("enabled", true);
try doc.setBool("debug", false);
```

**Output:**

```zig
.{
    .debug = false,
    .enabled = true,
}
```

### Integer Values

```zig
try doc.setInt("port", 8080);
try doc.setInt("max_connections", 100);

// Large hex values (automatically handled as i128 transitionally)
const fingerprint: u64 = 0xee480fa30d50cbf6;
try doc.setInt("fingerprint", @intCast(fingerprint));
```

**Output:**

```zig
.{
    .fingerprint = -6144092016769617084,
    .max_connections = 100,
    .port = 8080,
}
```

### Float Values

```zig
try doc.setFloat("pi", 3.14159);
try doc.setFloat("rate", 0.05);
```

**Output:**

```zig
.{
    .pi = 3.14159,
    .rate = 0.05,
}
```

### Special Float Values

Support for `inf`, `-inf`, and `nan`:

```zig
try doc.setFloat("limit", std.math.inf(f64));
try doc.setFloat("result", std.math.nan(f64));
```

**Output:**

```zig
.{
    .limit = inf,
    .result = nan,
}
```

### Null Values

```zig
try doc.setNull("password");
```

**Output:**

```zig
.{
    .password = null,
}
```

## Getting Values

All getters return `null` for missing paths or type mismatches.

### String Values

```zig
const name = doc.getString("name");

if (name) |n| {
    std.debug.print("Name: {s}\n", .{n});
} else {
    std.debug.print("Name not found\n", .{});
}

// With default
const version = doc.getString("version") orelse "0.0.0";
```

### Identifier Values

```zig
// Get identifier specifically
if (doc.getIdentifier("name")) |id| {
    std.debug.print("Package: .{s}\n", .{id});
}

// getString also works for identifiers
if (doc.getString("name")) |s| {
    std.debug.print("Name: {s}\n", .{s});
}

// Check if it's an identifier
if (doc.isIdentifier("name")) {
    std.debug.print("It's an identifier\n", .{});
}
```

### Boolean Values

```zig
const enabled = doc.getBool("enabled") orelse false;

if (enabled) {
    std.debug.print("Feature is enabled\n", .{});
}

// truthiness coercion (0, "", null, and empty collections are false)
if (doc.toBool("paths")) {
    std.debug.print("Paths array is not empty\n", .{});
}
```

### Integer Values

```zig
const port = doc.getInt("port") orelse 8080;
std.debug.print("Port: {d}\n", .{port});

// Large hex values / Unsigned integers
if (doc.getUint("fingerprint")) |fp| {
    std.debug.print("Fingerprint: 0x{x}\n", .{fp});
}
```

### Float Values

```zig
const rate = doc.getFloat("rate") orelse 0.0;
std.debug.print("Rate: {d}\n", .{rate});

// Special float checks
if (doc.isNan("result")) {
    std.debug.print("Calculation failed (NaN)\n", .{});
}
if (doc.isInf("limit")) {
    std.debug.print("Approaching infinity\n", .{});
}
```

## Checking Values

### Check if Path Exists

```zig
if (doc.exists("database.host")) {
    std.debug.print("Database host is configured\n", .{});
}
```

### Check if Null

```zig
if (doc.isNull("password")) {
    std.debug.print("Password is null\n", .{});
}
```

### Get Type Name

```zig
if (doc.getType("port")) |t| {
    std.debug.print("Type: {s}\n", .{t}); // "int"
}
```

Possible types:

- `"null"`
- `"bool"`
- `"int"`
- `"float"`
- `"string"`
- `"identifier"`
- `"object"`
- `"array"`

### Check if Empty

```zig
if (doc.isEmpty()) {
    std.debug.print("Document is empty\n", .{});
}
```

## Modifying Values

### Delete a Key

```zig
if (doc.delete("old_key")) {
    std.debug.print("Deleted successfully\n", .{});
} else {
    std.debug.print("Key didn't exist\n", .{});
}
```

### Clear All Data

```zig
doc.clear();
```

### Get Key Count

```zig
const count = doc.count();
std.debug.print("Root keys: {d}\n", .{count});
```

### Get All Keys

```zig
const keys = try doc.keys();
defer allocator.free(keys);

for (keys) |key| {
    std.debug.print("Key: {s}\n", .{key});
}
```

## Output

### To String

```zig
// Default (4-space indent)
const output = try doc.toString();
defer allocator.free(output);
std.debug.print("{s}\n", .{output});
```

### Pretty Print (Custom Indent)

```zig
// 2-space indent
const two_space = try doc.toPrettyString(2);
defer allocator.free(two_space);

// 8-space indent
const eight_space = try doc.toPrettyString(8);
defer allocator.free(eight_space);
```

### Compact (No Indent)

```zig
const compact = try doc.toCompactString();
defer allocator.free(compact);
```

## Saving

### Save to Original Path

```zig
// Only works if opened from file
try doc.save();
```

### Save to New Path

```zig
try doc.saveAs("config.zon");
```

## Complete Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Create document
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set various types
    try doc.setIdentifier("name", "my_app");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setBool("debug", true);
    try doc.setFloat("rate", 0.05);
    try doc.setNull("password");

    // Read values
    std.debug.print("Name: .{s}\n", .{doc.getIdentifier("name").?});
    std.debug.print("Port: {d}\n", .{doc.getInt("port").?});
    std.debug.print("Debug: {}\n", .{doc.getBool("debug").?});

    // Check types
    std.debug.print("Type of 'name': {s}\n", .{doc.getType("name").?});
    std.debug.print("Type of 'port': {s}\n", .{doc.getType("port").?});

    // Output
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("\n{s}\n", .{output});
}
```

**Output:**

```
Name: .my_app
Port: 8080
Debug: true
Type of 'name': identifier
Type of 'port': int

.{
    .debug = true,
    .name = .my_app,
    .password = null,
    .port = 8080,
    .rate = 0.05,
    .version = "1.0.0",
}
```
