const std = @import("std");
const build_options = @import("build_options");

pub const Environment = enum {
    local,
    production,

    pub fn fromString(str: []const u8) !Environment {
        if (std.mem.eql(u8, str, "local")) return .local;
        if (std.mem.eql(u8, str, "production")) return .production;
        return error.InvalidEnvironment;
    }
};

pub const AuthConfig = struct {
    header_name: []const u8,
    header_value: []const u8,
};

pub const Config = struct {
    base_url: []const u8,
    auth: AuthConfig,
    allocator: std.mem.Allocator,
    environment: Environment,

    pub fn deinit(self: *const Config) void {
        _ = self;
    }
};

pub fn getConfig(allocator: std.mem.Allocator, env: Environment) Config {
    const base_url = switch (env) {
        .local => build_options.LOCAL_BASE_URL,
        .production => build_options.PROD_BASE_URL,
    };

    const header_name = switch (env) {
        .local => build_options.LOCAL_AUTH_HEADER_NAME,
        .production => build_options.PROD_AUTH_HEADER_NAME,
    };

    const header_value = switch (env) {
        .local => build_options.LOCAL_AUTH_HEADER_VALUE,
        .production => build_options.PROD_AUTH_HEADER_VALUE,
    };

    return Config{
        .base_url = base_url,
        .auth = AuthConfig{
            .header_name = header_name,
            .header_value = header_value,
        },
        .allocator = allocator,
        .environment = env,
    };
}
