const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a step to copy .env file to src directory during build

    // Add clap module
    const clap = b.dependency("clap", .{});
    const clap_module = clap.module("clap");

    // Add modules
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

    // Make sure .env is copied before building

    // Add dependencies
    exe.root_module.addImport("clap", clap_module);
    exe.root_module.addImport("endpoint_config", endpoint_config_module);
    exe.root_module.addImport("env_config", env_config_module);
    exe.root_module.addImport("types", types_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .src_path = .{
            .owner = b,
            .sub_path = "src/main.zig",
        }},
        .target = target,
        .optimize = optimize,
    });

    // Add the same dependencies to the test executable
    unit_tests.root_module.addImport("clap", clap_module);
    unit_tests.root_module.addImport("endpoint_config", endpoint_config_module);
    unit_tests.root_module.addImport("env_config", env_config_module);
    unit_tests.root_module.addImport("types", types_module);


    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
