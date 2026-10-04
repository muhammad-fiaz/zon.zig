const std = @import("std");
const zon = @import("zon");

/// Example: Configuration file management
pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("=== Configuration Management Example ===\n\n", .{});

    var config = zon.create(allocator);
    defer config.deinit();

    try config.setString("app.name", "MyWebServer");
    try config.setString("app.version", "1.0.0");
    try config.setString("app.environment", "development");

    try config.setString("server.host", "0.0.0.0");
    try config.setInt("server.port", 8080);
    try config.setBool("server.ssl.enabled", false);
    try config.setString("server.ssl.cert_path", "/etc/ssl/cert.pem");
    try config.setString("server.ssl.keyPath", "/etc/ssl/key.pem");

    try config.setString("database.driver", "postgres");
    try config.setString("database.host", "localhost");
    try config.setInt("database.port", 5432);
    try config.setString("database.name", "myapp_dev");
    try config.setString("database.username", "admin");
    try config.setNull("database.password");
    try config.setInt("database.pool_size", 10);

    try config.setString("logging.level", "debug");
    try config.setString("logging.format", "json");
    try config.setBool("logging.colorize", true);

    try config.setInt("cache.ttl", 3600);
    try config.setString("cache.driver", "redis");
    try config.setString("cache.host", "localhost");
    try config.setInt("cache.port", 6379);

    std.debug.print("Development configuration:\n", .{});
    const devConfig = try config.toString();
    defer allocator.free(devConfig);
    std.debug.print("{s}\n\n", .{devConfig});

    std.debug.print("=== Creating production config with mergeRecursive ===\n\n", .{});

    var prodConfig = try config.clone();
    defer prodConfig.deinit();

    var overrides = zon.create(allocator);
    defer overrides.deinit();

    try overrides.setString("app.environment", "production");
    try overrides.setBool("server.ssl.enabled", true);
    try overrides.setString("database.host", "db.production.example.com");
    try overrides.setString("database.name", "myapp_prod");
    try overrides.setString("database.password", "secure_password_123");
    try overrides.setInt("database.pool_size", 50);
    try overrides.setString("logging.level", "warn");
    try overrides.setBool("logging.colorize", false);
    try overrides.setString("cache.host", "cache.production.example.com");

    try prodConfig.mergeRecursive(&overrides);

    std.debug.print("Production configuration:\n", .{});
    const prodStr = try prodConfig.toString();
    defer allocator.free(prodStr);
    std.debug.print("{s}\n", .{prodStr});

    std.debug.print("\n=== Configuration summary ===\n", .{});
    std.debug.print("Development:\n", .{});
    std.debug.print("  Environment: {s}\n", .{config.getString("app.environment").?});
    std.debug.print("  Database: {s}:{d}/{s}\n", .{
        config.getString("database.host").?,
        config.getInt("database.port").?,
        config.getString("database.name").?,
    });

    std.debug.print("\nProduction:\n", .{});
    std.debug.print("  Environment: {s}\n", .{prodConfig.getString("app.environment").?});
    std.debug.print("  Database: {s}:{d}/{s}\n", .{
        prodConfig.getString("database.host").?,
        prodConfig.getInt("database.port").?,
        prodConfig.getString("database.name").?,
    });
}
