const std = @import("std");
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // Get environment variables at build time
    var env = try std.process.getEnvMap(b.allocator);
    defer env.deinit();

    // Create build options
    const env_options = b.addOptions();

    // Required environment variables - fail if not present
    const local_base_url = env.get("LOCAL_BASE_URL") orelse {
        std.debug.print("Error: LOCAL_BASE_URL environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const local_auth_header_name = env.get("LOCAL_AUTH_HEADER_NAME") orelse {
        std.debug.print("Error: LOCAL_AUTH_HEADER_NAME environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const local_auth_header_value = env.get("LOCAL_AUTH_HEADER_VALUE") orelse {
        std.debug.print("Error: LOCAL_AUTH_HEADER_VALUE environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const prod_base_url = env.get("PROD_BASE_URL") orelse {
        std.debug.print("Error: PROD_BASE_URL environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const prod_auth_header_name = env.get("PROD_AUTH_HEADER_NAME") orelse {
        std.debug.print("Error: PROD_AUTH_HEADER_NAME environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const prod_auth_header_value = env.get("PROD_AUTH_HEADER_VALUE") orelse {
        std.debug.print("Error: PROD_AUTH_HEADER_VALUE environment variable must be set\n", .{});
        std.process.exit(1);
    };
    const my_user_id = env.get("MY_USER_ID") orelse "0";

    // Add environment variables to options
    env_options.addOption([]const u8, "LOCAL_BASE_URL", local_base_url);
    env_options.addOption([]const u8, "LOCAL_AUTH_HEADER_NAME", local_auth_header_name);
    env_options.addOption([]const u8, "LOCAL_AUTH_HEADER_VALUE", local_auth_header_value);
    env_options.addOption([]const u8, "PROD_BASE_URL", prod_base_url);
    env_options.addOption([]const u8, "PROD_AUTH_HEADER_NAME", prod_auth_header_name);
    env_options.addOption([]const u8, "PROD_AUTH_HEADER_VALUE", prod_auth_header_value);
    env_options.addOption([]const u8, "MY_USER_ID", my_user_id);

    // Create modules
    const env_options_module = env_options.createModule();
    const clap = b.dependency("clap", .{});
    const clap_module = clap.module("clap");
    const types_module = b.addModule("types", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/types.zig",
        } },
    });
    const env_config_module = b.addModule("env_config", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/env_config.zig",
        } },
        .imports = &.{
            .{ .name = "build_options", .module = env_options_module },
        },
    });
    const endpoint_config_module = b.addModule("endpoint_config", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/endpoint_config.zig",
        } },
        .imports = &.{
            .{ .name = "types", .module = types_module },
        },
    });

    const json_formatter_module = b.addModule("json_formatter", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/json_formatter.zig",
        } },
    });

    const utils_module = b.addModule("utils", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/utils.zig",
        } },
        .imports = &.{
            .{ .name = "types", .module = types_module },
            .{ .name = "endpoint_config", .module = endpoint_config_module },
        },
    });

    // Rest of your build configuration remains the same
    const exe = b.addExecutable(.{
        .name = "vlcli",
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        } },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("clap", clap_module);
    exe.root_module.addImport("endpoint_config", endpoint_config_module);
    exe.root_module.addImport("env_config", env_config_module);
    exe.root_module.addImport("types", types_module);
    exe.root_module.addImport("build_options", env_options_module);
    exe.root_module.addImport("json_formatter", json_formatter_module);
    exe.root_module.addImport("utils", utils_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        } },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("clap", clap_module);
    unit_tests.root_module.addImport("endpoint_config", endpoint_config_module);
    unit_tests.root_module.addImport("env_config", env_config_module);
    unit_tests.root_module.addImport("types", types_module);
    unit_tests.root_module.addImport("build_options", env_options_module);
    unit_tests.root_module.addImport("json_formatter", json_formatter_module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
