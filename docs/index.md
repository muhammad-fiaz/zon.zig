---
# https://vitepress.dev/reference/default-theme-home-page
layout: home
title: "zon.zig"
description: "zon.zig is a document-based Zig library for reading, writing, and manipulating ZON configuration files. Supports editing, find & replace, merge & clone, arrays, and pretty printing."
keywords:
  [
    "Zig",
    "ZON",
    "zon",
    "configuration",
    "parser",
    "serializer",
    "pretty-print",
    "std.zon",
  ]

hero:
  name: "ZON.zig"
  text: "Document-Based ZON Library"
  tagline: Read, write, and manipulate ZON files — complementary to std.zon
  image:
    src: /logo.svg
    alt: zon.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: API Reference
      link: /api/
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/zon.zig

features:
  - icon: 📄
    title: Document-Based API
    details: Maintains an in-memory document tree for editing and manipulation, unlike std.zon which parses into typed structures.
  - icon: 🔧
    title: Full ZON Support
    details: Supports all ZON types including identifiers (.name = .value), large hex numbers, arrays, and nested objects.
  - icon: 🔍
    title: Find & Replace
    details: Search for values across your document and replace them with a single function call.
  - icon: 🔄
    title: Merge & Clone
    details: Deep clone documents and merge configurations together for environment-specific setups.
  - icon: 🎨
    title: Pretty Print
    details: Configurable output formatting with custom indentation levels or compact output.
  - icon: ⚡
    title: Custom Parser
    details: Does NOT depend on std.zig.Ast or compiler internals. Provides diagnostic error reporting with line/column tracking.
  - icon: 🌐
    title: JSON Interoperability
    details: Import from and Export to standard JSON seamlessly. Ideal for data transformation and cross-tooling.
  - icon: 🛡️
    title: Integrity Suite
    details: Stable order-independent hashing and cryptographic checksums for document validation.
  - icon: 🏗️
    title: Flatten & Expand
    details: Convert nested configurations to flat maps for environment overrides and simplified summaries.
---

## Quick Start

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

    try doc.setIdentifier("name", "my_app");
    try doc.setString("version", "1.0.0");
    try doc.setInt("port", 8080);
    try doc.setString("database.host", "localhost");

    try doc.saveAs("config.zon");
}
```

**Output (`config.zon`):**

```zig
.{
    .database = .{
        .host = "localhost",
    },
    .name = .my_app,
    .port = 8080,
    .version = "1.0.0",
}
```

## Installation

### Release Installation (Recommended)

Install the latest stable release (v0.0.4):

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.4.tar.gz
```

### Nightly Installation

Install the latest development version:

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zon.zig
```

### Configure build.zig

Then in your `build.zig`:

```zig
const zon_dep = b.dependency("zon", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zon", zon_dep.module("zon"));
```

## License

MIT License - [View on GitHub](https://github.com/muhammad-fiaz/zon.zig/blob/main/LICENSE)
