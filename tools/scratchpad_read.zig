// Scratchpad Read Tool - Read current scratchpad content (Time-Keeper memory tool)
const std = @import("std");
const ollama = @import("ollama");
const permission = @import("permission");
const context_module = @import("context");
const tools_module = @import("../tools.zig");

const AppContext = context_module.AppContext;
const ToolDefinition = tools_module.ToolDefinition;
const ToolResult = tools_module.ToolResult;

pub fn getDefinition(allocator: std.mem.Allocator) !ToolDefinition {
    return .{
        .ollama_tool = .{
            .type = "function",
            .function = .{
                .name = try allocator.dupe(u8, "scratchpad_read"),
                .description = try allocator.dupe(u8, "Read the current scratchpad content. Returns the raw text stored in the scratchpad, or empty string if scratchpad is empty."),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {},
                    \\  "required": []
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "scratchpad_read",
            .description = "Read from scratchpad memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    _ = arguments;
    const start_time = std.time.milliTimestamp();

    const content = context.state.readScratchpad();

    if (content.len == 0) {
        return ToolResult.ok(allocator, "(scratchpad is empty)", start_time, null);
    }

    return ToolResult.ok(allocator, content, start_time, null);
}
