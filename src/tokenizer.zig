//! Tokenizer - Lexical analysis for ZON source code.
//!
//! This module provides a tokenizer that converts ZON source text into a stream of tokens.
//! It handles all ZON lexical elements including identifiers, strings, numbers, and punctuation.
//!
//! ## Supported Tokens
//!
//! | Token | Example |
//! |-------|---------|
//! | `.` | Dot |
//! | `{` `}` | Braces |
//! | `[` `]` | Brackets |
//! | `,` | Comma |
//! | `=` | Equals |
//! | `:` | Colon |
//! | `@` | At sign |
//! | `"..."` | String literal |
//! | `'...'` | Character literal |
//! | `123`, `0xFF` | Number literal |
//! | `true`, `false`, `null` | Keywords |
//! | `name` | Identifier |
//!

const std = @import("std");

/// Represents a single token from the source.
pub const Token = struct {
    /// The type of token.
    tag: Tag,
    /// Start position in the source.
    start: usize,
    /// End position in the source (exclusive).
    end: usize,

    /// Token types.
    pub const Tag = enum {
        /// `.`
        dot,
        /// `{`
        l_brace,
        /// `}`
        r_brace,
        /// `[`
        l_bracket,
        /// `]`
        r_bracket,
        /// `,`
        comma,
        /// `=`
        equals,
        /// `:`
        colon,
        /// An identifier (variable name, key name)
        identifier,
        /// A string literal `"..."`
        string_literal,
        /// A multiline string literal `\\...`
        multiline_string_literal,
        /// A character literal `'...'`
        char_literal,
        /// A number literal (integer or float)
        number_literal,
        /// The `true` keyword
        keyword_true,
        /// The `false` keyword
        keyword_false,
        /// The `null` keyword
        keyword_null,
        /// `@`
        at_sign,
        /// `-`
        minus,
        /// `+`
        plus,
        /// `// ...`
        comment,
        /// `/// ...`
        doc_comment,
        /// End of file
        eof,
        /// Invalid token
        invalid,
    };
};

/// Tokenizes ZON source code.
///
/// Create with `init()`, then call `next()` repeatedly to get tokens.
pub const Tokenizer = struct {
    /// The source being tokenized.
    source: []const u8,
    /// Current position in the source.
    index: usize,

    /// Creates a new tokenizer for the given source.
    pub fn init(source: []const u8) Tokenizer {
        return .{
            .source = source,
            .index = 0,
        };
    }

    /// Returns the next token from the source.
    ///
    /// Returns `.eof` when the end of the source is reached.
    pub fn next(self: *Tokenizer) Token {
        self.skipWhitespaceAndComments();

        const start = self.index;

        if (self.index >= self.source.len) {
            return .{ .tag = .eof, .start = start, .end = start };
        }

        const c = self.source[self.index];

        switch (c) {
            '.' => {
                self.index += 1;
                return .{ .tag = .dot, .start = start, .end = self.index };
            },
            '{' => {
                self.index += 1;
                return .{ .tag = .l_brace, .start = start, .end = self.index };
            },
            '}' => {
                self.index += 1;
                return .{ .tag = .r_brace, .start = start, .end = self.index };
            },
            '[' => {
                self.index += 1;
                return .{ .tag = .l_bracket, .start = start, .end = self.index };
            },
            ']' => {
                self.index += 1;
                return .{ .tag = .r_bracket, .start = start, .end = self.index };
            },
            ',' => {
                self.index += 1;
                return .{ .tag = .comma, .start = start, .end = self.index };
            },
            '=' => {
                self.index += 1;
                return .{ .tag = .equals, .start = start, .end = self.index };
            },
            ':' => {
                self.index += 1;
                return .{ .tag = .colon, .start = start, .end = self.index };
            },
            '@' => {
                self.index += 1;
                return .{ .tag = .at_sign, .start = start, .end = self.index };
            },
            '/' => {
                if (self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                    const is_doc = if (self.index + 2 < self.source.len and self.source[self.index + 2] == '/') true else false;
                    self.index += if (is_doc) @as(usize, 3) else @as(usize, 2);
                    while (self.index < self.source.len and self.source[self.index] != '\n') {
                        self.index += 1;
                    }
                    return .{ .tag = if (is_doc) .doc_comment else .comment, .start = start, .end = self.index };
                }
                self.index += 1;
                return .{ .tag = .invalid, .start = start, .end = self.index };
            },
            '-' => {
                if (self.index + 1 < self.source.len and isDigit(self.source[self.index + 1])) {
                    return self.scanNumber();
                }
                self.index += 1;
                return .{ .tag = .minus, .start = start, .end = self.index };
            },
            '+' => {
                if (self.index + 1 < self.source.len and isDigit(self.source[self.index + 1])) {
                    return self.scanNumber();
                }
                self.index += 1;
                return .{ .tag = .plus, .start = start, .end = self.index };
            },
            '"' => return self.scanString(),
            '\'' => return self.scanChar(),
            '\\' => {
                if (self.index + 1 < self.source.len and self.source[self.index + 1] == '\\') {
                    return self.scanMultilineString();
                }
                self.index += 1;
                return .{ .tag = .invalid, .start = start, .end = self.index };
            },
            '0'...'9' => return self.scanNumber(),
            'a'...'z', 'A'...'Z', '_' => return self.scanIdentifier(),
            else => {
                self.index += 1;
                return .{ .tag = .invalid, .start = start, .end = self.index };
            },
        }
    }

    /// Skips whitespace and returns next non-whitespace/comment token.
    pub fn nextValid(self: *Tokenizer) Token {
        while (true) {
            const tok = self.next();
            switch (tok.tag) {
                .comment, .doc_comment => continue,
                else => return tok,
            }
        }
    }

    /// Calculates the line number (1-based) for the given byte offset.
    pub fn lineAt(self: *const Tokenizer, offset: usize) usize {
        var line: usize = 1;
        var i: usize = 0;
        const target = @min(offset, self.source.len);
        while (i < target) : (i += 1) {
            if (self.source[i] == '\n') line += 1;
        }
        return line;
    }

    /// Calculates the column number (1-based) for the given byte offset.
    pub fn columnAt(self: *const Tokenizer, offset: usize) usize {
        var col: usize = 1;
        var i: usize = 0;
        const target = @min(offset, self.source.len);
        while (i < target) : (i += 1) {
            if (self.source[i] == '\n') {
                col = 1;
            } else {
                col += 1;
            }
        }
        return col;
    }

    /// Skips whitespace.
    fn skipWhitespace(self: *Tokenizer) void {
        while (self.index < self.source.len) {
            const c = self.source[self.index];
            switch (c) {
                ' ', '\t', '\n', '\r' => self.index += 1,
                else => return,
            }
        }
    }

    /// Skips whitespace and line comments (compat alias).
    fn skipWhitespaceAndComments(self: *Tokenizer) void {
        while (self.index < self.source.len) {
            const c = self.source[self.index];
            switch (c) {
                ' ', '\t', '\n', '\r' => self.index += 1,
                '/' => {
                    if (self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                        self.index += 2;
                        while (self.index < self.source.len and self.source[self.index] != '\n') {
                            self.index += 1;
                        }
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    /// Scans a string literal.
    fn scanString(self: *Tokenizer) Token {
        const start = self.index;
        self.index += 1;

        while (self.index < self.source.len) {
            const c = self.source[self.index];
            if (c == '"') {
                self.index += 1;
                return .{ .tag = .string_literal, .start = start, .end = self.index };
            } else if (c == '\\') {
                self.index += 2;
            } else {
                self.index += 1;
            }
        }

        return .{ .tag = .invalid, .start = start, .end = self.index };
    }

    /// Scans a multiline string literal.
    fn scanMultilineString(self: *Tokenizer) Token {
        const start = self.index;
        self.index += 2; // skip \\

        while (self.index < self.source.len) {
            const c = self.source[self.index];
            if (c == '\n') break;
            self.index += 1;
        }

        return .{ .tag = .multiline_string_literal, .start = start, .end = self.index };
    }

    /// Scans a character literal.
    fn scanChar(self: *Tokenizer) Token {
        const start = self.index;
        self.index += 1;

        while (self.index < self.source.len) {
            const c = self.source[self.index];
            if (c == '\'') {
                self.index += 1;
                return .{ .tag = .char_literal, .start = start, .end = self.index };
            } else if (c == '\\') {
                self.index += 2;
            } else {
                self.index += 1;
            }
        }

        return .{ .tag = .invalid, .start = start, .end = self.index };
    }

    /// Scans a number literal.
    ///
    /// Supports decimal, hexadecimal (0x), octal (0o), binary (0b), and floats.
    fn scanNumber(self: *Tokenizer) Token {
        const start = self.index;

        if (self.source[self.index] == '-' or self.source[self.index] == '+') {
            self.index += 1;
        }

        if (self.index < self.source.len and self.source[self.index] == '0') {
            self.index += 1;
            if (self.index < self.source.len) {
                switch (self.source[self.index]) {
                    'x', 'X' => {
                        self.index += 1;
                        while (self.index < self.source.len and isHexDigit(self.source[self.index])) {
                            self.index += 1;
                        }
                        return .{ .tag = .number_literal, .start = start, .end = self.index };
                    },
                    'o', 'O' => {
                        self.index += 1;
                        while (self.index < self.source.len and isOctalDigit(self.source[self.index])) {
                            self.index += 1;
                        }
                        return .{ .tag = .number_literal, .start = start, .end = self.index };
                    },
                    'b', 'B' => {
                        self.index += 1;
                        while (self.index < self.source.len and isBinaryDigit(self.source[self.index])) {
                            self.index += 1;
                        }
                        return .{ .tag = .number_literal, .start = start, .end = self.index };
                    },
                    else => {},
                }
            }
        }

        while (self.index < self.source.len and isDigit(self.source[self.index])) {
            self.index += 1;
        }

        if (self.index < self.source.len and self.source[self.index] == '.') {
            if (self.index + 1 < self.source.len and isDigit(self.source[self.index + 1])) {
                self.index += 1;
                while (self.index < self.source.len and isDigit(self.source[self.index])) {
                    self.index += 1;
                }
            }
        }

        if (self.index < self.source.len and (self.source[self.index] == 'e' or self.source[self.index] == 'E')) {
            self.index += 1;
            if (self.index < self.source.len and (self.source[self.index] == '+' or self.source[self.index] == '-')) {
                self.index += 1;
            }
            while (self.index < self.source.len and isDigit(self.source[self.index])) {
                self.index += 1;
            }
        }

        return .{ .tag = .number_literal, .start = start, .end = self.index };
    }

    /// Scans an identifier or keyword.
    fn scanIdentifier(self: *Tokenizer) Token {
        const start = self.index;

        while (self.index < self.source.len) {
            const c = self.source[self.index];
            if (isAlphaNumeric(c) or c == '_') {
                self.index += 1;
            } else {
                break;
            }
        }

        const ident = self.source[start..self.index];

        const tag: Token.Tag = if (std.mem.eql(u8, ident, "true"))
            .keyword_true
        else if (std.mem.eql(u8, ident, "false"))
            .keyword_false
        else if (std.mem.eql(u8, ident, "null"))
            .keyword_null
        else
            .identifier;

        return .{ .tag = tag, .start = start, .end = self.index };
    }

    /// Returns the source text for a token.
    pub fn slice(self: *const Tokenizer, token: Token) []const u8 {
        return self.source[token.start..token.end];
    }
};

/// Load file contents into an allocator-owned buffer suitable for tokenizing.
/// Caller is responsible for freeing the returned buffer via the same allocator.
pub fn loadSourceFromFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, 1024 * 1024 * 64);
}

// Character Classification Helpers

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isHexDigit(c: u8) bool {
    return isDigit(c) or (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F');
}

fn isOctalDigit(c: u8) bool {
    return c >= '0' and c <= '7';
}

fn isBinaryDigit(c: u8) bool {
    return c == '0' or c == '1';
}

fn isAlphaNumeric(c: u8) bool {
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c == '_';
}

test "tokenize: dot" {
    var tokenizer = Tokenizer.init(".");
    const tok = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.dot, tok.tag);
}

test "tokenize: braces" {
    var tokenizer = Tokenizer.init("{}");
    try std.testing.expectEqual(Token.Tag.l_brace, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.r_brace, tokenizer.next().tag);
}

test "tokenize: brackets" {
    var tokenizer = Tokenizer.init("[]");
    try std.testing.expectEqual(Token.Tag.l_bracket, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.r_bracket, tokenizer.next().tag);
}

test "tokenize: comma" {
    var tokenizer = Tokenizer.init(",");
    try std.testing.expectEqual(Token.Tag.comma, tokenizer.next().tag);
}

test "tokenize: equals" {
    var tokenizer = Tokenizer.init("=");
    try std.testing.expectEqual(Token.Tag.equals, tokenizer.next().tag);
}

test "tokenize: identifier" {
    var tokenizer = Tokenizer.init("hello_world");
    const tok = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.identifier, tok.tag);
    try std.testing.expectEqualStrings("hello_world", tokenizer.slice(tok));
}

test "tokenize: string literal" {
    var tokenizer = Tokenizer.init("\"hello world\"");
    const tok = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.string_literal, tok.tag);
}

test "tokenize: number literal" {
    var tokenizer = Tokenizer.init("12345");
    const tok = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.number_literal, tok.tag);
    try std.testing.expectEqualStrings("12345", tokenizer.slice(tok));
}

test "tokenize: hex number" {
    var tokenizer = Tokenizer.init("0xFF");
    const tok = tokenizer.next();
    try std.testing.expectEqual(Token.Tag.number_literal, tok.tag);
    try std.testing.expectEqualStrings("0xFF", tokenizer.slice(tok));
}

test "tokenize: keyword true" {
    var tokenizer = Tokenizer.init("true");
    try std.testing.expectEqual(Token.Tag.keyword_true, tokenizer.next().tag);
}

test "tokenize: keyword false" {
    var tokenizer = Tokenizer.init("false");
    try std.testing.expectEqual(Token.Tag.keyword_false, tokenizer.next().tag);
}

test "tokenize: keyword null" {
    var tokenizer = Tokenizer.init("null");
    try std.testing.expectEqual(Token.Tag.keyword_null, tokenizer.next().tag);
}

test "tokenize: skip comment" {
    var tokenizer = Tokenizer.init("// comment\n.{");
    try std.testing.expectEqual(Token.Tag.dot, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.l_brace, tokenizer.next().tag);
}

test "tokenize: at sign" {
    var tokenizer = Tokenizer.init("@");
    try std.testing.expectEqual(Token.Tag.at_sign, tokenizer.next().tag);
}

test "tokenize: eof" {
    var tokenizer = Tokenizer.init("");
    try std.testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}

test "tokenize: full object" {
    var tokenizer = Tokenizer.init(".{ .name = \"test\" }");
    try std.testing.expectEqual(Token.Tag.dot, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.l_brace, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.dot, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.identifier, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.equals, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.string_literal, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.r_brace, tokenizer.next().tag);
    try std.testing.expectEqual(Token.Tag.eof, tokenizer.next().tag);
}
