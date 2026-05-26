const std = @import("std");
const zon = @import("zon");

/// Example: Creating deeply nested ZON structures
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    std.debug.print("=== Nested ZON Creation Example ===\n\n", .{});

    var doc = zon.create(allocator);
    defer doc.deinit();

    // Level 1: Package info
    try doc.setString("name", "my_web_app");
    try doc.setString("version", "1.0.0");
    try doc.setString("description", "A full-featured web application");

    // Level 2: Server configuration
    try doc.setString("server.host", "0.0.0.0");
    try doc.setInt("server.port", 8080);
    try doc.setBool("server.debug", true);

    // Level 3: SSL configuration (nested inside server)
    try doc.setBool("server.ssl.enabled", true);
    try doc.setString("server.ssl.cert_path", "/etc/ssl/certs/server.crt");
    try doc.setString("server.ssl.key_path", "/etc/ssl/private/server.key");
    try doc.setInt("server.ssl.port", 443);

    // Level 3: CORS configuration (nested inside server)
    try doc.setBool("server.cors.enabled", true);
    try doc.setString("server.cors.origin", "*");
    try doc.setInt("server.cors.max_age", 86400);

    // Level 2: Database configuration
    try doc.setString("database.driver", "postgres");
    try doc.setString("database.host", "localhost");
    try doc.setInt("database.port", 5432);
    try doc.setString("database.name", "myapp_db");
    try doc.setString("database.username", "app_user");
    try doc.setNull("database.password");

    // Level 3: Connection pool settings
    try doc.setInt("database.pool.min_size", 5);
    try doc.setInt("database.pool.max_size", 20);
    try doc.setInt("database.pool.idle_timeout", 300);

    // Level 2: Cache configuration
    try doc.setString("cache.driver", "redis");
    try doc.setString("cache.host", "localhost");
    try doc.setInt("cache.port", 6379);
    try doc.setInt("cache.ttl", 3600);
    try doc.setString("cache.prefix", "myapp:");

    // Level 3: Cache cluster settings
    try doc.setBool("cache.cluster.enabled", false);
    try doc.setInt("cache.cluster.nodes", 3);

    // Level 2: Logging configuration
    try doc.setString("logging.level", "info");
    try doc.setString("logging.format", "json");
    try doc.setBool("logging.colorize", true);

    // Level 3: Log file settings
    try doc.setString("logging.file.path", "/var/log/myapp/app.log");
    try doc.setBool("logging.file.enabled", true);
    try doc.setInt("logging.file.max_size_mb", 100);
    try doc.setInt("logging.file.max_files", 10);

    // Level 2: API configuration
    try doc.setString("api.version", "v1");
    try doc.setString("api.base_path", "/api");
    try doc.setInt("api.rate_limit", 1000);
    try doc.setInt("api.timeout_ms", 30000);

    // Level 3: API authentication
    try doc.setString("api.auth.type", "jwt");
    try doc.setInt("api.auth.token_expiry", 3600);
    try doc.setString("api.auth.issuer", "myapp.example.com");

    // Level 2: Features flags
    try doc.setBool("features.user_registration", true);
    try doc.setBool("features.email_verification", true);
    try doc.setBool("features.two_factor_auth", false);
    try doc.setBool("features.social_login", true);

    // Level 2: Dependencies (as nested objects)
    try doc.setString("dependencies.http.url", "https://github.com/example/http");
    try doc.setString("dependencies.http.hash", "abc123def456");

    try doc.setString("dependencies.json.url", "https://github.com/example/json");
    try doc.setString("dependencies.json.hash", "def456ghi789");

    try doc.setString("dependencies.crypto.url", "https://github.com/example/crypto");
    try doc.setString("dependencies.crypto.hash", "ghi789jkl012");

    // Display the structure
    std.debug.print("Created nested structure:\n\n", .{});
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});

    // Demonstrate reading nested values
    std.debug.print("\n=== Reading Nested Values ===\n", .{});
    std.debug.print("Server port: {d}\n", .{doc.getInt("server.port").?});
    std.debug.print("SSL enabled: {}\n", .{doc.getBool("server.ssl.enabled").?});
    std.debug.print("SSL cert: {s}\n", .{doc.getString("server.ssl.cert_path").?});
    std.debug.print("DB pool max: {d}\n", .{doc.getInt("database.pool.max_size").?});
    std.debug.print("API auth type: {s}\n", .{doc.getString("api.auth.type").?});
    std.debug.print("HTTP dep hash: {s}\n", .{doc.getString("dependencies.http.hash").?});

    // Save to file
    try doc.saveAs("nested_config.zon");
    std.debug.print("\nSaved to nested_config.zon\n", .{});

    // Cleanup
    try zon.deleteFile("nested_config.zon");
}
