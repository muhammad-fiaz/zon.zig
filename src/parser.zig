//! Parser - Parses ZON source into a Value tree.
//!
//! This module provides a custom ZON parser that converts source text into a structured
//! Value representation. Unlike `std.zon.parse` which deserializes directly into Zig types,
//! this parser creates an intermediate Value tree for document manipulation.
//!
//! Key differences from std.zon:
//! - Does NOT rely on `std.zig.Ast`, `Zoir`, or Zig compiler internals
//! - Produces a mutable Value tree instead of typed data
//! - Designed for configuration file editing and dynamic access
//!
//! Supported Syntax:
//! - Objects: `.{ .key = value, .key2 = value2 }`
//! - Arrays: `.{ value1, value2 }` or `.{ "string1", "string2" }`
//! - Strings: `"hello"`, `@"with spaces"`
//! - Identifiers as values: `.name = .zon` (stored as string "zon")
//! - Numbers: `123`, `-45`, `3.14`, `0xFF`, `0xee480fa30d50cbf6`
//! - Booleans: `true`, `false`
//! - Null: `null`
//! - Comments: `// line comment`
//! - Trailing commas are allowed

const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Tokenizer = @import("tokenizer.zig").Tokenizer;
const Token = @import("tokenizer.zig").Token;
const Value = @import("value.zig").Value;

/// Errors that can occur during parsing.
pub const ParseError = error{
    UnexpectedToken,
    InvalidNumber,
    InvalidString,
    UnterminatedString,
    OutOfMemory,
};

/// Parses ZON source code into a Value tree.
pub const Parser = struct {
    allocator: Allocator,
    tokenizer: Tokenizer,
    current: Token,

    /// Creates a new parser for the given source.
    pub fn init(allocator: Allocator, source: []const u8) Parser {
        var tokenizer = Tokenizer.init(source);
        const current = tokenizer.next();
        return .{
            .allocator = allocator,
            .tokenizer = tokenizer,
            .current = current,
        };
    }

    /// Parses the source and returns the root Value.
    pub fn parse(self: *Parser) ParseError!Value {
        return self.parseValue();
    }

    fn advance(self: *Parser) void {
        self.current = self.tokenizer.next();
    }

    fn expect(self: *Parser, tag: Token.Tag) ParseError!void {
        if (self.current.tag != tag) {
            return error.UnexpectedToken;
        }
        self.advance();
    }

    fn parseValue(self: *Parser) ParseError!Value {
        switch (self.current.tag) {
            .dot => return self.parseObjectOrEnum(),
            .keyword_true => {
                self.advance();
                return .{ .bool_val = true };
            },
            .keyword_false => {
                self.advance();
                return .{ .bool_val = false };
            },
            .keyword_null => {
                self.advance();
                return .null_val;
            },
            .string_literal => return self.parseString(),
            .multiline_string_literal => return self.parseMultilineString(),
            .char_literal => return self.parseChar(),
            .number_literal => return self.parseNumber(),
            .identifier => {
                const slice = self.tokenizer.slice(self.current);
                if (std.mem.eql(u8, slice, "true")) {
                    self.advance();
                    return .{ .bool_val = true };
                } else if (std.mem.eql(u8, slice, "false")) {
                    self.advance();
                    return .{ .bool_val = false };
                } else if (std.mem.eql(u8, slice, "null")) {
                    self.advance();
                    return .null_val;
                } else if (std.mem.eql(u8, slice, "inf")) {
                    self.advance();
                    return .{ .number = .{ .float = std.math.inf(f64) } };
                } else if (std.mem.eql(u8, slice, "nan")) {
                    self.advance();
                    return .{ .number = .{ .float = std.math.nan(f64) } };
                }
                return error.UnexpectedToken;
            },
            .minus => {
                self.advance();
                const val = try self.parseValue();
                return switch (val) {
                    .number => |n| switch (n) {
                        .int => |i| .{ .number = .{ .int = -i } },
                        .float => |f| .{ .number = .{ .float = -f } },
                    },
                    else => error.UnexpectedToken,
                };
            },
            .plus => {
                self.advance();
                return self.parseValue();
            },
            .at_sign => return self.parseAtExpression(),
            else => return error.UnexpectedToken,
        }
    }

    fn parseObjectOrEnum(self: *Parser) ParseError!Value {
        try self.expect(.dot);

        if (self.current.tag == .l_brace) {
            return self.parseObjectOrArray();
        } else if (self.current.tag == .l_bracket) {
            return self.parseBracketArray();
        } else if (self.current.tag == .identifier) {
            const name = try self.allocator.dupe(u8, self.tokenizer.slice(self.current));
            self.advance();
            return .{ .identifier = name };
        }

        return error.UnexpectedToken;
    }

    fn parseObjectOrArray(self: *Parser) ParseError!Value {
        try self.expect(.l_brace);

        if (self.current.tag == .r_brace) {
            self.advance();
            return .{ .object = Value.Object.init(self.allocator) };
        }

        if (self.current.tag == .dot) {
            var temp_tokenizer = self.tokenizer;
            const peek = temp_tokenizer.next();
            if (peek.tag == .identifier) {
                var temp2 = temp_tokenizer;
                const peek2 = temp2.next();
                if (peek2.tag == .equals) {
                    return self.parseObjectBody();
                }
            }
        }

        return self.parseArrayBody();
    }

    fn parseObjectBody(self: *Parser) ParseError!Value {
        var obj = Value.Object.init(self.allocator);
        errdefer obj.deinit();

        while (self.current.tag != .r_brace and self.current.tag != .eof) {
            if (self.current.tag == .dot) {
                self.advance();

                if (self.current.tag != .identifier) {
                    return error.UnexpectedToken;
                }

                const key = try self.allocator.dupe(u8, self.tokenizer.slice(self.current));
                errdefer self.allocator.free(key);
                self.advance();

                try self.expect(.equals);

                const value = try self.parseValue();
                try obj.entries.put(self.allocator, key, value);

                if (self.current.tag == .comma) {
                    self.advance();
                }
            } else {
                break;
            }
        }

        try self.expect(.r_brace);
        return .{ .object = obj };
    }

    fn parseArrayBody(self: *Parser) ParseError!Value {
        var arr = Value.Array.init(self.allocator);
        errdefer arr.deinit();

        while (self.current.tag != .r_brace and self.current.tag != .eof) {
            const value = try self.parseValue();
            try arr.append(value);

            if (self.current.tag == .comma) {
                self.advance();
            } else if (self.current.tag != .r_brace) {
                break;
            }
        }

        try self.expect(.r_brace);
        return .{ .array = arr };
    }

    fn parseBracketArray(self: *Parser) ParseError!Value {
        try self.expect(.l_bracket);

        var arr = Value.Array.init(self.allocator);
        errdefer arr.deinit();

        while (self.current.tag != .r_bracket and self.current.tag != .eof) {
            const value = try self.parseValue();
            try arr.append(value);

            if (self.current.tag == .comma) {
                self.advance();
            } else {
                break;
            }
        }

        try self.expect(.r_bracket);
        return .{ .array = arr };
    }

    fn parseAtExpression(self: *Parser) ParseError!Value {
        try self.expect(.at_sign);

        if (self.current.tag != .string_literal) {
            return error.UnexpectedToken;
        }

        return self.parseString();
    }

    fn parseString(self: *Parser) ParseError!Value {
        const raw = self.tokenizer.slice(self.current);
        self.advance();

        if (raw.len < 2) {
            return error.InvalidString;
        }

        const content = raw[1 .. raw.len - 1];
        const unescaped = try self.unescapeString(content);

        return .{ .string = unescaped };
    }

    fn parseMultilineString(self: *Parser) ParseError!Value {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        while (self.current.tag == .multiline_string_literal) {
            const raw = self.tokenizer.slice(self.current);
            // Skip the leading \\
            if (raw.len >= 2) {
                try result.appendSlice(self.allocator, raw[2..]);
            }
            self.advance();
            if (self.current.tag == .multiline_string_literal) {
                try result.append(self.allocator, '\n');
            }
        }

        return .{ .string = try result.toOwnedSlice(self.allocator) };
    }

    fn parseChar(self: *Parser) ParseError!Value {
        const raw = self.tokenizer.slice(self.current);
        self.advance();

        if (raw.len < 2) {
            return error.InvalidString;
        }

        const content = raw[1 .. raw.len - 1];
        const unescaped = try self.unescapeString(content);

        return .{ .string = unescaped };
    }

    fn unescapeString(self: *Parser, input: []const u8) ParseError![]u8 {
        var result: std.ArrayListUnmanaged(u8) = .empty;
        errdefer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < input.len) {
            if (input[i] == '\\' and i + 1 < input.len) {
                switch (input[i + 1]) {
                    'n' => try result.append(self.allocator, '\n'),
                    'r' => try result.append(self.allocator, '\r'),
                    't' => try result.append(self.allocator, '\t'),
                    '\\' => try result.append(self.allocator, '\\'),
                    '"' => try result.append(self.allocator, '"'),
                    '\'' => try result.append(self.allocator, '\''),
                    '0' => try result.append(self.allocator, 0),
                    'x' => {
                        if (i + 3 < input.len) {
                            const hex = input[i + 2 .. i + 4];
                            const byte = std.fmt.parseInt(u8, hex, 16) catch {
                                try result.append(self.allocator, input[i]);
                                try result.append(self.allocator, input[i + 1]);
                                i += 2;
                                continue;
                            };
                            try result.append(self.allocator, byte);
                            i += 4;
                            continue;
                        } else {
                            try result.append(self.allocator, input[i]);
                            try result.append(self.allocator, input[i + 1]);
                        }
                    },
                    'u' => {
                        if (i + 2 < input.len and input[i + 2] == '{') {
                            var end = i + 3;
                            while (end < input.len and input[end] != '}') : (end += 1) {}
                            if (end < input.len) {
                                const hex = input[i + 3 .. end];
                                const codepoint = std.fmt.parseInt(u21, hex, 16) catch {
                                    try result.append(self.allocator, input[i]);
                                    try result.append(self.allocator, input[i + 1]);
                                    i += 2;
                                    continue;
                                };
                                var buf: [4]u8 = undefined;
                                const len = std.unicode.utf8Encode(codepoint, &buf) catch {
                                    try result.append(self.allocator, input[i]);
                                    try result.append(self.allocator, input[i + 1]);
                                    i += 2;
                                    continue;
                                };
                                try result.appendSlice(self.allocator, buf[0..len]);
                                i = end + 1;
                                continue;
                            }
                        }
                        try result.append(self.allocator, input[i]);
                        try result.append(self.allocator, input[i + 1]);
                    },
                    else => {
                        try result.append(self.allocator, input[i]);
                        try result.append(self.allocator, input[i + 1]);
                    },
                }
                i += 2;
            } else {
                try result.append(self.allocator, input[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }

    fn parseNumber(self: *Parser) ParseError!Value {
        const raw = self.tokenizer.slice(self.current);
        self.advance();

        if (std.mem.indexOfScalar(u8, raw, '.') != null or
            std.mem.indexOfScalar(u8, raw, 'e') != null or
            std.mem.indexOfScalar(u8, raw, 'E') != null)
        {
            const is_hex = raw.len > 2 and raw[0] == '0' and (raw[1] == 'x' or raw[1] == 'X');
            if (!is_hex) {
                const val = std.fmt.parseFloat(f64, raw) catch return error.InvalidNumber;
                return .{ .number = .{ .float = val } };
            }
        }

        if (raw.len > 2 and raw[0] == '0') {
            switch (raw[1]) {
                'x', 'X' => {
                    const val = std.fmt.parseInt(u128, raw[2..], 16) catch return error.InvalidNumber;
                    return .{ .number = .{ .int = @bitCast(val) } };
                },
                'o', 'O' => {
                    const val = std.fmt.parseInt(i128, raw[2..], 8) catch return error.InvalidNumber;
                    return .{ .number = .{ .int = val } };
                },
                'b', 'B' => {
                    const val = std.fmt.parseInt(i128, raw[2..], 2) catch return error.InvalidNumber;
                    return .{ .number = .{ .int = val } };
                },
                else => {},
            }
        }

        const val = std.fmt.parseInt(i128, raw, 10) catch return error.InvalidNumber;
        return .{ .number = .{ .int = val } };
    }
};

/// Parses ZON source and returns the root Value.
/// This is the main entry point for parsing ZON.
pub fn parse(allocator: Allocator, source: []const u8) ParseError!Value {
    var p = Parser.init(allocator, source);
    return p.parse();
}

/// Parse ZON from a file on disk.
pub fn parseFile(allocator: Allocator, path: []const u8) ParseError!Value {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024 * 64);
    defer allocator.free(source);

    return parse(allocator, source);
}

test "parse object" {
    const allocator = std.testing.allocator;
    const source = ".{ .name = \"test\" }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
}

test "parse array with strings" {
    const allocator = std.testing.allocator;
    const source =
        \\.{
        \\    "build.zig",
        \\    "build.zig.zon",
        \\    "src",
        \\}
    ;
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .array);
    try std.testing.expectEqual(@as(usize, 3), value.array.len());
}

test "parse enum value as identifier" {
    const allocator = std.testing.allocator;
    const source = ".{ .name = .zon }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const name = obj.get("name").?;
    try std.testing.expectEqualStrings("zon", name.asString().?);
}

test "parse large hex fingerprint" {
    const allocator = std.testing.allocator;
    const source = ".{ .fingerprint = 0xee480fa30d50cbf6 }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const fp = obj.get("fingerprint").?;
    try std.testing.expect(fp.asUint() != null);
    try std.testing.expectEqual(@as(u64, 0xee480fa30d50cbf6), fp.asUint().?);
}

test "parse build.zig.zon style" {
    const allocator = std.testing.allocator;
    const source =
        \\.{
        \\    .name = .zon,
        \\    .version = "0.0.3",
        \\    .fingerprint = 0xee480fa30d50cbf6,
        \\    .minimum_zig_version = "0.15.0",
        \\    .paths = .{
        \\        "build.zig",
        \\        "build.zig.zon",
        \\        "src",
        \\    },
        \\}
    ;
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    try std.testing.expect(value == .object);
    var obj = value.asObject().?;

    const name = obj.get("name").?;
    try std.testing.expectEqualStrings("zon", name.asString().?);

    const version = obj.get("version").?;
    try std.testing.expectEqualStrings("0.0.3", version.asString().?);

    const fp = obj.get("fingerprint").?;
    try std.testing.expect(fp.asUint() != null);

    const paths = obj.get("paths").?;
    try std.testing.expect(paths.* == .array);
    try std.testing.expectEqual(@as(usize, 3), paths.array.len());
}

test "parse hex number" {
    const allocator = std.testing.allocator;
    const source = ".{ .value = 0xFF }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const val = obj.get("value").?;
    try std.testing.expectEqual(@as(i64, 255), val.asInt().?);
}

test "parse binary number" {
    const allocator = std.testing.allocator;
    const source = ".{ .value = 0b1010 }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const val = obj.get("value").?;
    try std.testing.expectEqual(@as(i64, 10), val.asInt().?);
}

test "parse octal number" {
    const allocator = std.testing.allocator;
    const source = ".{ .value = 0o755 }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const val = obj.get("value").?;
    try std.testing.expectEqual(@as(i64, 493), val.asInt().?);
}

test "parse identifier value" {
    const allocator = std.testing.allocator;
    const source = ".{ .name = .my_package }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const val = obj.get("name").?;
    try std.testing.expect(val.isIdentifier());
    try std.testing.expectEqualStrings("my_package", val.asIdentifier().?);
}

test "parse nested object" {
    const allocator = std.testing.allocator;
    const source = ".{ .server = .{ .host = \"localhost\", .port = 8080 } }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const server = obj.get("server").?.asObject().?;
    try std.testing.expectEqualStrings("localhost", server.get("host").?.asString().?);
    try std.testing.expectEqual(@as(i64, 8080), server.get("port").?.asInt().?);
}

test "parse mixed array" {
    const allocator = std.testing.allocator;
    const source = ".{ .items = .{ \"a\", \"b\", \"c\" } }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    const arr = obj.get("items").?.asArray().?;
    try std.testing.expectEqual(@as(usize, 3), arr.len());
    try std.testing.expectEqualStrings("a", arr.get(0).?.asString().?);
}

test "parse null value" {
    const allocator = std.testing.allocator;
    const source = ".{ .value = null }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    try std.testing.expect(obj.get("value").?.isNull());
}

test "parse boolean values" {
    const allocator = std.testing.allocator;
    const source = ".{ .enabled = true, .disabled = false }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    try std.testing.expectEqual(true, obj.get("enabled").?.asBool().?);
    try std.testing.expectEqual(false, obj.get("disabled").?.asBool().?);
}

test "parse float" {
    const allocator = std.testing.allocator;
    const source = ".{ .value = 3.14159 }";
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    try std.testing.expectApproxEqAbs(@as(f64, 3.14159), obj.get("value").?.asFloat().?, 0.00001);
}

test "parse multiline string" {
    const allocator = std.testing.allocator;
    const source =
        \\.{
        \\    .text = \\line 1
        \\            \\line 2
        \\}
    ;
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    try std.testing.expectEqualStrings("line 1\nline 2", obj.get("text").?.asString().?);
}

test "parse build.zig.zon format" {
    const allocator = std.testing.allocator;
    const source =
        \\.{
        \\    .name = .my_lib,
        \\    .version = "0.1.0",
        \\    .paths = .{
        \\        "build.zig",
        \\        "src",
        \\    },
        \\}
    ;
    var value = try parse(allocator, source);
    defer value.deinit(allocator);

    var obj = value.asObject().?;
    try std.testing.expect(obj.get("name").?.isIdentifier());
    try std.testing.expectEqualStrings("my_lib", obj.get("name").?.asIdentifier().?);
    try std.testing.expectEqualStrings("0.1.0", obj.get("version").?.asString().?);

    const paths = obj.get("paths").?.asArray().?;
    try std.testing.expectEqual(@as(usize, 2), paths.len());
}
