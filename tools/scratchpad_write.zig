// Scratchpad Write Tool - Write/replace entire scratchpad content (Time-Keeper memory tool)
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
                .name = try allocator.dupe(u8, "scratchpad_write"),
                .description = try allocator.dupe(u8, "Write/replace entire scratchpad content. Use for unstructured notes and summaries. Example: {\"text\": \"User prefers vegetarian food\\nBudget: $50\"} returns {\"status\": \"success\", \"length\": 42}"),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "text": {
                    \\      "type": "string",
                    \\      "description": "Text content to write to the scratchpad (replaces existing content)"
                    \\    }
                    \\  },
                    \\  "required": ["text"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "scratchpad_write",
            .description = "Write to scratchpad memory",
            .risk_level = .safe,
            .required_scopes = &.{.todo_management},
            .validator = null,
        },
        .execute = execute,
    };
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    const Args = struct { text: []const u8 };
    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(allocator, .parse_error, "Invalid JSON arguments. Expected: {\"text\": \"...\"}", start_time);
    };
    defer parsed.deinit();

    context.state.writeScratchpad(parsed.value.text) catch |err| {
        const msg = try std.fmt.allocPrint(allocator, "Failed to write to scratchpad: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    const result_msg = try std.fmt.allocPrint(allocator, "{{\"status\": \"success\", \"length\": {d}}}", .{parsed.value.text.len});
    defer allocator.free(result_msg);
    return ToolResult.ok(allocator, result_msg, start_time, null);
}
