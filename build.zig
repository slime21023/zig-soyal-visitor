const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "soyal-visitor",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the CLI tool");
    run_step.dependOn(&run_cmd.step);

    // 測試步驟
    const validator_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/validators.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const converter_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/converters.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_validator_tests = b.addRunArtifact(validator_tests);
    const run_converter_tests = b.addRunArtifact(converter_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_validator_tests.step);
    test_step.dependOn(&run_converter_tests.step);
}
