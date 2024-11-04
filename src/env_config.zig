const std = @import("std");

pub const AuthConfig = struct {
    header_name: []const u8,
    header_value: []const u8,
};

pub const Config = struct {
    base_url: []const u8,
    auth: AuthConfig,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const Config) void {
        _ = self;
    }
};

// Compile-time environment loader
const Env = struct {
    const env_contents = @embedFile(".env");

    pub fn get(comptime key: []const u8) ?[]const u8 {
        @setEvalBranchQuota(100000);
        comptime {
            var it = std.mem.splitScalar(u8, env_contents, '\n');
            while (it.next()) |line| {
                if (line.len == 0 or line[0] == '#') continue;

                const maybe_eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
                const line_key = line[0..maybe_eq];
                const line_value = line[maybe_eq + 1 ..];

                if (std.mem.eql(u8, key, line_key)) {
                    return line_value;
                }
            }
            return null;
        }
    }

    pub fn require(comptime key: []const u8) []const u8 {
        return get(key) orelse @compileError("Required environment variable '" ++ key ++ "' not found in .env file");
    }
};

pub const Environment = enum {
    local,
    production,

    pub fn getEnvVar(self: Environment, comptime key: []const u8) []const u8 {
        const prefix = switch (self) {
            .local => "LOCAL_",
            .production => "PROD_",
        };
        return Env.require(prefix ++ key);
    }
};

pub fn getConfig(allocator: std.mem.Allocator, env: Environment) !Config {
    // Verify all required env vars exist at comptime
    comptime {
        _ = Environment.local.getEnvVar("BASE_URL");
        _ = Environment.local.getEnvVar("AUTH_HEADER_NAME");
        _ = Environment.local.getEnvVar("AUTH_HEADER_VALUE");
        _ = Environment.production.getEnvVar("BASE_URL");
        _ = Environment.production.getEnvVar("AUTH_HEADER_NAME");
        _ = Environment.production.getEnvVar("AUTH_HEADER_VALUE");
    }

    return Config{
        .base_url = env.getEnvVar("BASE_URL"),
        .auth = AuthConfig{
            .header_name = env.getEnvVar("AUTH_HEADER_NAME"),
            .header_value = env.getEnvVar("AUTH_HEADER_VALUE"),
        },
        .allocator = allocator,
    };
}
