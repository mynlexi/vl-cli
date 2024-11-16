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
    myUserId: ?[]const u8,
    allocator: std.mem.Allocator,
    environment: Environment,

    pub fn deinit(self: *const Config) void {
        _ = self;
    }
};

pub fn getMyUserId() ?[]const u8 {
    const myUserId: ?[]const u8 = if (std.mem.eql(u8, build_options.MY_USER_ID, "0"))
        null
    else
        build_options.MY_USER_ID;
    return myUserId;
}

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

    const myUserId: ?[]const u8 = getMyUserId();

    return Config{
        .base_url = base_url,
        .auth = AuthConfig{
            .header_name = header_name,
            .header_value = header_value,
        },
        .myUserId = myUserId,
        .allocator = allocator,
        .environment = env,
    };
}
