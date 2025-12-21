---
title: "Reading Files"
description: "Reading ZON files from disk and parsing from strings; tips for handling large files and errors."
---

# Reading Files

Comprehensive guide to reading ZON files and data.

## Opening Existing Files

The standard workflow for interacting with an existing ZON configuration on disk involves **Opening**, **Reading/Querying**, and **Closing**.

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // 1. OPEN: Load and parse the file from disk
    var doc = try zon.open(allocator, "config.zon");

    // 2. READ: Query values using path-based access
    if (doc.getString("name")) |name| {
        std.debug.print("Project Name: {s}\n", .{name});
    }

    // 3. CLOSE: Free memory when finished
    doc.close();
}
```

### Automatic Error Handling

`zon.open` handles file access and parsing in one step. It will return errors if the file is missing, inaccessible, or contains invalid ZON syntax.

```zig
var doc = zon.open(allocator, "settings.zon") catch |err| {
    std.debug.print("Failed to load config: {any}\n", .{err});
    return err;
};
defer doc.close();
```

## Parse from String

```zig
const source =
    \\.{
    \\    .name = "myapp",
    \\    .version = "1.0.0",
    \\    .port = 8080,
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.close();
```

## Read String Values

```zig
// Basic read
const name = doc.getString("name");
if (name) |n| {
    std.debug.print("Name: {s}\n", .{n});
}

// With default
const version = doc.getString("version") orelse "0.0.0";
std.debug.print("Version: {s}\n", .{version});
```

**Example File (`config.zon`):**

```zig
.{
    .name = "myapp",
    .version = "1.0.0",
}
```

**Output:**

```
Name: myapp
Version: 1.0.0
```

## Read Identifier Values

Identifiers are values like `.name = .my_package`:

```zig
// Get identifier specifically
if (doc.getIdentifier("name")) |id| {
    std.debug.print("Package: .{s}\n", .{id});
}

// getString also works
if (doc.getString("name")) |s| {
    std.debug.print("Package: {s}\n", .{s});
}

// Check if it's an identifier
if (doc.isIdentifier("name")) {
    std.debug.print("name is an identifier type\n", .{});
}
```

**Example File:**

```zig
.{
    .name = .my_package,
}
```

**Output:**

```
Package: .my_package
Package: my_package
name is an identifier type
```

## Read Numeric Values

### Integers

```zig
const port = doc.getInt("port") orelse 8080;
std.debug.print("Port: {d}\n", .{port});
```

### Large Hex Values (Fingerprints)

```zig
if (doc.getUint("fingerprint")) |fp| {
    std.debug.print("Fingerprint: 0x{x}\n", .{fp});
}
```

**Example File:**

```zig
.{
    .port = 8080,
    .fingerprint = 0xee480fa30d50cbf6,
}
```

**Output:**

```
Port: 8080
Fingerprint: 0xee480fa30d50cbf6
```

### Floats

```zig
const rate = doc.getFloat("rate") orelse 0.0;
std.debug.print("Rate: {d}\n", .{rate});
```

## Read Boolean Values

```zig
const enabled = doc.getBool("enabled") orelse false;
const debug = doc.getBool("debug") orelse false;

std.debug.print("Enabled: {}\n", .{enabled});
std.debug.print("Debug: {}\n", .{debug});
```

**Example File:**

```zig
.{
    .enabled = true,
    .debug = false,
}
```

**Output:**

```
Enabled: true
Debug: false
```

## Read Nested Values

Use dot notation for nested paths:

```zig
const host = doc.getString("database.host") orelse "localhost";
const db_port = doc.getInt("database.port") orelse 5432;
const ssl = doc.getBool("database.ssl.enabled") orelse false;

std.debug.print("Host: {s}\n", .{host});
std.debug.print("Port: {d}\n", .{db_port});
std.debug.print("SSL: {}\n", .{ssl});
```

**Example File:**

```zig
.{
    .database = .{
        .host = "localhost",
        .port = 5432,
        .ssl = .{
            .enabled = true,
        },
    },
}
```

**Output:**

```
Host: localhost
Port: 5432
SSL: true
```

## Read Arrays

### Get Array Length

```zig
if (doc.arrayLen("paths")) |len| {
    std.debug.print("Paths: {d} items\n", .{len});
}
```

### Iterate Array Strings

```zig
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("  [{d}] {s}\n", .{i, path});
}
```

### Get Specific Index

```zig
if (doc.getArrayString("paths", 0)) |first| {
    std.debug.print("First path: {s}\n", .{first});
}

if (doc.getArrayInt("numbers", 2)) |num| {
    std.debug.print("Third number: {d}\n", .{num});
}
```

**Example File:**

```zig
.{
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
    .numbers = .{
        10,
        20,
        30,
    },
}
```

**Output:**

```
Paths: 3 items
  [0] build.zig
  [1] build.zig.zon
  [2] src
First path: build.zig
Third number: 30
```

## Check Values

### Path Exists

```zig
if (doc.exists("database.host")) {
    std.debug.print("Database is configured\n", .{});
} else {
    std.debug.print("Using defaults\n", .{});
}
```

### Is Null

```zig
if (doc.isNull("password")) {
    std.debug.print("Password not set\n", .{});
}
```

### Get Type

```zig
if (doc.getType("port")) |t| {
    std.debug.print("Type of port: {s}\n", .{t});
}
```

Possible types: `"null"`, `"bool"`, `"int"`, `"float"`, `"string"`, `"identifier"`, `"object"`, `"array"`

## Read build.zig.zon

```zig
const source =
    \\.{
    \\    .name = .my_package,
    \\    .version = "0.1.0",
    \\    .fingerprint = 0xee480fa30d50cbf6,
    \\    .minimum_zig_version = "0.15.0",
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src",
    \\    },
    \\    .dependencies = .{
    \\        .http = .{
    \\            .url = "https://github.com/example/http",
    \\            .hash = "abc123def456",
    \\        },
    \\    },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Package name (identifier)
std.debug.print("Package: .{s}\n", .{doc.getIdentifier("name").?});

// Version
std.debug.print("Version: {s}\n", .{doc.getString("version").?});

// Fingerprint (getUint recommended for u64)
if (doc.getUint("fingerprint")) |fp| {
    std.debug.print("Fingerprint: 0x{x}\n", .{fp});
}

// Paths
std.debug.print("Paths:\n", .{});
var i: usize = 0;
while (doc.getArrayString("paths", i)) |path| : (i += 1) {
    std.debug.print("  - {s}\n", .{path});
}

// Dependencies
if (doc.getString("dependencies.http.url")) |url| {
    std.debug.print("HTTP dep: {s}\n", .{url});
}
```

**Output:**

```
Package: .my_package
Version: 0.1.0
Fingerprint: 0xee480fa30d50cbf6
Paths:
  - build.zig
  - build.zig.zon
  - src
HTTP dep: https://github.com/example/http
```

## Error Handling

```zig
// Open with error handling
var doc = zon.open(allocator, "config.zon") catch |err| {
    switch (err) {
        error.FileNotFound => {
            std.debug.print("Config file not found, using defaults\n", .{});
            return;
        },
        else => return err,
    }
};
defer doc.deinit();

// Parse with error handling
var parsed = zon.parse(allocator, source) catch |err| {
    std.debug.print("Parse error: {}\n", .{err});
    return;
};
defer parsed.deinit();
```

## File Utilities

```zig
// Check if file exists before opening
if (zon.fileExists("config.zon")) {
    var doc = try zon.open(allocator, "config.zon");
    defer doc.deinit();
    // ...
}
```
