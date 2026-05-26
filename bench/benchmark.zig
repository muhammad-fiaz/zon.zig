//! Comprehensive benchmarks for zon.zig covering all features.
//! Tests parsing, stringify, manipulation, type checking, case utilities,
//! sorting, array operations, vectorized ops, and struct conversion.

const std = @import("std");
const zon = @import("zon");
const builtin = @import("builtin");

const BenchmarkResult = struct {
    name: []const u8,
    iterations: u64,
    total_time_ns: u64,
    ops_per_sec: f64,
    avg_latency_ns: f64,
    category: []const u8,

    const categories = [_][]const u8{
        "Parsing",
        "Stringify",
        "Manipulation",
        "Type Checking",
        "Case Utilities",
        "Sorting",
        "Array Operations",
        "Vectorized Ops",
        "Struct Conversion",
    };
};

const ITERATIONS = 10_000;
const WARMUP = 100;

fn printResults(results: []const BenchmarkResult) void {
    std.debug.print("\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});
    std.debug.print("                                 ZON.ZIG BENCHMARK RESULTS\n", .{});
    std.debug.print("-" ** 100, .{});
    std.debug.print("\n", .{});

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        std.debug.print("\n[{s}]\n", .{cat});
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});
        std.debug.print("{s:<40} {s:>25} {s:>25}\n", .{ "Benchmark", "Ops/sec", "Avg Latency (ns)" });
        std.debug.print("-" ** 100, .{});
        std.debug.print("\n", .{});

        for (results) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                std.debug.print("{s:<50} {d:>25.0} {d:>30.0}\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                });
            }
        }
    }

    std.debug.print("\n", .{});
    std.debug.print("=" ** 130, .{});
    std.debug.print("\n", .{});
}

fn runBenchmark(
    name: []const u8,
    allocator: std.mem.Allocator,
    comptime benchFn: anytype,
    category: []const u8,
) !BenchmarkResult {
    for (0..WARMUP) |_| {
        try benchFn(allocator);
    }

    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();
    const start_time = std.Io.Clock.awake.now(io);
    for (0..ITERATIONS) |_| {
        try benchFn(allocator);
    }
    const total_time_ns = @as(u64, @intCast(start_time.untilNow(io, .awake).toNanoseconds()));

    const ops_per_sec = @as(f64, @floatFromInt(ITERATIONS)) / (@as(f64, @floatFromInt(total_time_ns)) / 1_000_000_000.0);
    const avg_latency_ns = @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(ITERATIONS));

    return BenchmarkResult{
        .name = name,
        .iterations = ITERATIONS,
        .total_time_ns = total_time_ns,
        .ops_per_sec = ops_per_sec,
        .avg_latency_ns = avg_latency_ns,
        .category = category,
    };
}

const PARSE_SOURCE =
    \\.{
    \\    .name = "benchmark_pkg",
    \\    .version = "0.1.0",
    \\    .dependencies = .{
    \\        .foo = .{
    \\            .url = "https://github.com/foo/foo",
    \\            .hash = "1234567890abcdef",
    \\        },
    \\        .bar = .{
    \\            .path = "../bar",
    \\        },
    \\    },
    \\    .paths = .{
    \\        "build.zig",
    \\        "build.zig.zon",
    \\        "src/main.zig",
    \\        "README.md",
    \\    },
    \\    .meta = .{
    \\        .author = "Performance Tester",
    \\        .license = "MIT",
    \\    },
    \\}
;

const IDENTIFIER_SOURCE =
    \\.{
    \\    .name = .benchmark_pkg,
    \\    .version = "0.1.0",
    \\    .minimum_zig_version = "0.16.0",
    \\}
;

const NESTED_SOURCE =
    \\.{
    \\    .server = .{
    \\        .host = "localhost",
    \\        .port = 8080,
    \\        .ssl = .{
    \\            .enabled = true,
    \\            .cert_path = "/etc/ssl/cert.pem",
    \\        },
    \\        .tags = .{"web", "api", "v1"},
    \\    },
    \\    .database = .{
    \\        .host = "db.local",
    \\        .port = 5432,
    \\        .pool = .{
    \\            .min = 5,
    \\            .max = 20,
    \\        },
    \\    },
    \\}
;

fn benchParse(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, PARSE_SOURCE);
    doc.deinit();
}

fn benchParseIdentifier(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, IDENTIFIER_SOURCE);
    doc.deinit();
}

fn benchParseNested(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, NESTED_SOURCE);
    doc.deinit();
}

fn benchStringify(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, PARSE_SOURCE);
    defer doc.deinit();
    const s = try doc.toString();
    allocator.free(s);
}

fn benchStringifyCompact(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, PARSE_SOURCE);
    defer doc.deinit();
    const s = try doc.toCompactString();
    allocator.free(s);
}

fn benchAccess(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, ".{ .a = 1, .b = 2, .c = .{ .d = 3 } }");
    defer doc.deinit();
    var sum: i64 = 0;
    for (0..100) |_| {
        sum += doc.getInt("a").?;
        sum += doc.getInt("b").?;
        sum += doc.getInt("c.d").?;
    }
    std.mem.doNotOptimizeAway(sum);
}

fn benchModification(allocator: std.mem.Allocator) !void {
    var doc = zon.create(allocator);
    defer doc.deinit();
    for (0..100) |i| {
        try doc.setInt("count", @intCast(i));
        try doc.setBool("active", i % 2 == 0);
    }
}

fn benchTypeChecking(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, ".{ .s = \"hi\", .i = 42, .b = true, .f = 1.5 }");
    defer doc.deinit();
    var check: bool = true;
    check = check and doc.isString("s");
    check = check and doc.isInt("i");
    check = check and doc.isBool("b");
    check = check and doc.isFloat("f");
    check = check and doc.isNumber("i");
    check = check and !doc.isString("i");
    std.mem.doNotOptimizeAway(check);
}

fn benchNestedTypeChecking(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, NESTED_SOURCE);
    defer doc.deinit();
    var check: bool = true;
    check = check and doc.isString("server.host");
    check = check and doc.isInt("server.port");
    check = check and doc.isObject("server.ssl");
    check = check and doc.isBool("server.ssl.enabled");
    check = check and doc.isArray("server.tags");
    std.mem.doNotOptimizeAway(check);
}

fn benchCaseUpper(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, ".{ .name = \"hello\" }");
    defer doc.deinit();
    doc.toUpper("name") catch {};
}

fn benchCaseLower(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, ".{ .name = \"HELLO\" }");
    defer doc.deinit();
    doc.toLower("name") catch {};
}

fn benchCaseCheck(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator, ".{ .name = \"HELLO\" }");
    defer doc.deinit();
    var check: bool = true;
    check = check and doc.isUpperCase("name");
    std.mem.doNotOptimizeAway(check);
}

fn benchSortKeys(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .z = 1, .m = 2, .a = 3, .nested = .{ .y = 4, .b = 5 } }
    );
    defer doc.deinit();
    doc.sortKeys();
}

fn benchSortKeysDesc(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .a = 1, .m = 2, .z = 3 }
    );
    defer doc.deinit();
    doc.sortKeysDesc();
}

fn benchSortArray(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"z", "m", "a", "y", "b", "x"} }
    );
    defer doc.deinit();
    doc.sortArray("arr") catch {};
}

fn benchReverseArray(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{1, 2, 3, 4, 5} }
    );
    defer doc.deinit();
    doc.reverseArray("arr") catch {};
}

fn benchTruncate(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"a", "b", "c", "d", "e"} }
    );
    defer doc.deinit();
    doc.truncate("arr", 2) catch {};
}

fn benchDropFirst(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"a", "b", "c", "d", "e"} }
    );
    defer doc.deinit();
    doc.dropFirst("arr", 2) catch {};
}

fn benchDropLast(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"a", "b", "c", "d", "e"} }
    );
    defer doc.deinit();
    doc.dropLast("arr", 2) catch {};
}

fn benchCompact(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"a", null, "b", null, "c"} }
    );
    defer doc.deinit();
    doc.compact("arr") catch {};
}

fn benchUnique(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"a", "b", "a", "c", "b", "a"} }
    );
    defer doc.deinit();
    doc.unique("arr") catch {};
}

fn benchEvery(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{2, 4, 6, 8, 10} }
    );
    defer doc.deinit();
    const Pred = struct {
        fn isEven(v: *const zon.Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) == 0;
        }
    };
    const all = doc.every("arr", Pred.isEven);
    std.mem.doNotOptimizeAway(all);
}

fn benchSome(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{1, 3, 5, 7, 8} }
    );
    defer doc.deinit();
    const Pred = struct {
        fn isEven(v: *const zon.Value) bool {
            const i = v.asInt() orelse return false;
            return @rem(i, 2) == 0;
        }
    };
    const any = doc.some("arr", Pred.isEven);
    std.mem.doNotOptimizeAway(any);
}

fn benchFirstLast(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{ .arr = .{"first", "middle", "last"} }
    );
    defer doc.deinit();
    const f = doc.first("arr");
    const l = doc.last("arr");
    std.mem.doNotOptimizeAway(f);
    std.mem.doNotOptimizeAway(l);
}

const BenchStruct = struct {
    name: []const u8,
    version: []const u8,
    count: u32,
    active: bool,
    tags: []const []const u8,
};

fn benchToStruct(allocator: std.mem.Allocator) !void {
    var doc = try zon.parse(allocator,
        \\.{
        \\    .name = "bench",
        \\    .version = "1.0.0",
        \\    .count = 42,
        \\    .active = true,
        \\    .tags = .{ "a", "b", "c" },
        \\}
    );
    defer doc.deinit();
    const s = try doc.toStruct(BenchStruct);
    allocator.free(s.name);
    allocator.free(s.version);
    allocator.free(s.tags);
}

fn benchFromStruct(allocator: std.mem.Allocator) !void {
    const s = BenchStruct{
        .name = "bench",
        .version = "1.0.0",
        .count = 42,
        .active = true,
        .tags = &.{ "a", "b", "c" },
    };
    var doc = try zon.fromStruct(allocator, s);
    doc.deinit();
}

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var results: std.ArrayList(BenchmarkResult) = .empty;
    defer results.deinit(allocator);

    zon.disableUpdateCheck();

    // Parsing
    try results.append(allocator, try runBenchmark("Parse Standard ZON", allocator, benchParse, "Parsing"));
    try results.append(allocator, try runBenchmark("Parse Identifiers", allocator, benchParseIdentifier, "Parsing"));
    try results.append(allocator, try runBenchmark("Parse Nested ZON", allocator, benchParseNested, "Parsing"));

    // Stringify
    try results.append(allocator, try runBenchmark("Stringify to ZON", allocator, benchStringify, "Stringify"));
    try results.append(allocator, try runBenchmark("Stringify Compact", allocator, benchStringifyCompact, "Stringify"));

    // Manipulation
    try results.append(allocator, try runBenchmark("Read Access (100 ops)", allocator, benchAccess, "Manipulation"));
    try results.append(allocator, try runBenchmark("Modification (100 ops)", allocator, benchModification, "Manipulation"));

    // Type Checking
    try results.append(allocator, try runBenchmark("Type Check Flat", allocator, benchTypeChecking, "Type Checking"));
    try results.append(allocator, try runBenchmark("Type Check Nested", allocator, benchNestedTypeChecking, "Type Checking"));

    // Case Utilities
    try results.append(allocator, try runBenchmark("toUpper String", allocator, benchCaseUpper, "Case Utilities"));
    try results.append(allocator, try runBenchmark("toLower String", allocator, benchCaseLower, "Case Utilities"));
    try results.append(allocator, try runBenchmark("isUpperCase Check", allocator, benchCaseCheck, "Case Utilities"));

    // Sorting
    try results.append(allocator, try runBenchmark("sortKeys Asc", allocator, benchSortKeys, "Sorting"));
    try results.append(allocator, try runBenchmark("sortKeys Desc", allocator, benchSortKeysDesc, "Sorting"));
    try results.append(allocator, try runBenchmark("sortArray", allocator, benchSortArray, "Sorting"));
    try results.append(allocator, try runBenchmark("reverseArray", allocator, benchReverseArray, "Sorting"));

    // Array Operations
    try results.append(allocator, try runBenchmark("truncate Array", allocator, benchTruncate, "Array Operations"));
    try results.append(allocator, try runBenchmark("dropFirst Array", allocator, benchDropFirst, "Array Operations"));
    try results.append(allocator, try runBenchmark("dropLast Array", allocator, benchDropLast, "Array Operations"));
    try results.append(allocator, try runBenchmark("compact Array", allocator, benchCompact, "Array Operations"));
    try results.append(allocator, try runBenchmark("unique Array", allocator, benchUnique, "Array Operations"));
    try results.append(allocator, try runBenchmark("first/last Access", allocator, benchFirstLast, "Array Operations"));

    // Vectorized Ops
    try results.append(allocator, try runBenchmark("every (all match)", allocator, benchEvery, "Vectorized Ops"));
    try results.append(allocator, try runBenchmark("some (any match)", allocator, benchSome, "Vectorized Ops"));

    // Struct Conversion
    try results.append(allocator, try runBenchmark("Document to Struct", allocator, benchToStruct, "Struct Conversion"));
    try results.append(allocator, try runBenchmark("Struct to Document", allocator, benchFromStruct, "Struct Conversion"));

    // Print all results to console
    printResults(results.items);

    // Summary Statistics
    var total_ops: f64 = 0;
    var max_ops: f64 = 0;
    var min_ops: f64 = std.math.floatMax(f64);
    var count: usize = 0;
    var max_name: []const u8 = "";
    var min_name: []const u8 = "";

    for (results.items) |r| {
        total_ops += r.ops_per_sec;
        count += 1;
        if (r.ops_per_sec > max_ops) {
            max_ops = r.ops_per_sec;
            max_name = r.name;
        }
        if (r.ops_per_sec < min_ops) {
            min_ops = r.ops_per_sec;
            min_name = r.name;
        }
    }

    const avg_ops = if (count > 0) total_ops / @as(f64, @floatFromInt(count)) else 0;
    const avg_latency = if (avg_ops > 0) 1_000_000_000.0 / avg_ops else 0;

    // Write final Markdown report
    var report: std.ArrayList(u8) = .empty;
    defer report.deinit(allocator);

    const md_header =
        \\#### 📊 ZON.ZIG BENCHMARK RESULTS
        \\
        \\**Environment Details:**
        \\- **Platform:** {s}
        \\- **Architecture:** {s}
        \\- **Warmup Iterations:** {d}
        \\- **Benchmark Iterations:** {d}
        \\
        \\
    ;

    var header_buf: [1024]u8 = undefined;
    const header = std.fmt.bufPrint(&header_buf, md_header, .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
        WARMUP,
        ITERATIONS,
    }) catch "";
    try report.appendSlice(allocator, header);

    for (BenchmarkResult.categories) |cat| {
        var has_category = false;
        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                has_category = true;
                break;
            }
        }
        if (!has_category) continue;

        const cat_md = try std.fmt.allocPrint(allocator,
            \\
            \\<details>
            \\<summary><strong>{s}</strong></summary>
            \\
            \\| Benchmark | Ops/sec (higher is better) | Avg Latency (ns) (lower is better) |
            \\| :--- | :--- | :--- |
            \\
        , .{cat});
        defer allocator.free(cat_md);
        try report.appendSlice(allocator, cat_md);

        for (results.items) |r| {
            if (std.mem.eql(u8, r.category, cat)) {
                var line_buf: [1024]u8 = undefined;
                const line = std.fmt.bufPrint(&line_buf, "| {s} | {d:.0} | {d:.0} |\n", .{
                    r.name,
                    r.ops_per_sec,
                    r.avg_latency_ns,
                }) catch continue;
                try report.appendSlice(allocator, line);
            }
        }
        try report.appendSlice(allocator, "</details>\n");
    }

    if (count > 0) {
        try report.appendSlice(allocator, "\n### 📈 Benchmark Summary\n\n");
        var summary_buf: [1024]u8 = undefined;
        const summary = std.fmt.bufPrint(&summary_buf,
            \\- **Total benchmarks run:** {d}
            \\- **Average throughput:** {d:.0} ops/sec
            \\- **Maximum throughput:** {d:.0} ops/sec ({s})
            \\- **Minimum throughput:** {d:.0} ops/sec ({s})
            \\- **Average latency:** {d:.0} ns
            \\
        , .{ count, avg_ops, max_ops, max_name, min_ops, min_name, avg_latency }) catch "";
        try report.appendSlice(allocator, summary);
    }

    zon.writeFileAtomic(allocator, "benchmark-results.md", report.items) catch |err| {
        std.debug.print("Warning: Could not create benchmark-results.md: {}\n", .{err});
    };

    std.debug.print("[OK] Benchmarks completed successfully!\n", .{});
}
