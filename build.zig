const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get environment variables at build time
    var env = try std.process.getEnvMap(b.allocator);
    defer env.deinit();

    // Create build options
    const env_options = b.addOptions();

    // Add all environment variables
    env_options.addOption([]const u8, "LOCAL_BASE_URL",
        env.get("LOCAL_BASE_URL") orelse "http://localhost:3000");
    env_options.addOption([]const u8, "LOCAL_AUTH_HEADER_NAME",
        env.get("LOCAL_AUTH_HEADER_NAME") orelse "X-Auth-Token");
    env_options.addOption([]const u8, "LOCAL_AUTH_HEADER_VALUE",
        env.get("LOCAL_AUTH_HEADER_VALUE") orelse "local_dev_key_here");
    env_options.addOption([]const u8, "PROD_BASE_URL",
        env.get("PROD_BASE_URL") orelse "https://app.getvoiceline.com");
    env_options.addOption([]const u8, "PROD_AUTH_HEADER_NAME",
        env.get("PROD_AUTH_HEADER_NAME") orelse "Voiceline-Search-Auth");
    env_options.addOption([]const u8, "PROD_AUTH_HEADER_VALUE",
        env.get("PROD_AUTH_HEADER_VALUE") orelse "your_prod_key_here");

    // Create modules
    const env_options_module = env_options.createModule();
    const clap = b.dependency("clap", .{});
    const clap_module = clap.module("clap");

    const types_module = b.addModule("types", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/types.zig",
        }},
    });

    const env_config_module = b.addModule("env_config", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/env_config.zig",
        }},
        .imports = &.{
            .{ .name = "build_options", .module = env_options_module },
        },
    });

    const endpoint_config_module = b.addModule("endpoint_config", .{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/endpoint_config.zig",
        }},
        .imports = &.{
            .{ .name = "types", .module = types_module },
        },
    });

    const exe = b.addExecutable(.{
        .name = "vlcli",
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        }},
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies
    exe.root_module.addImport("clap", clap_module);
    exe.root_module.addImport("endpoint_config", endpoint_config_module);
    exe.root_module.addImport("env_config", env_config_module);
    exe.root_module.addImport("types", types_module);
    exe.root_module.addImport("build_options", env_options_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test setup
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        }},
        .target = target,
        .optimize = optimize,
    });

    unit_tests.root_module.addImport("clap", clap_module);
    unit_tests.root_module.addImport("endpoint_config", endpoint_config_module);
    unit_tests.root_module.addImport("env_config", env_config_module);
    unit_tests.root_module.addImport("types", types_module);
    unit_tests.root_module.addImport("build_options", env_options_module);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
