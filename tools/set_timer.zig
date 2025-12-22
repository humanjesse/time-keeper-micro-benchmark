// Set Timer Tool - Fire-and-forget timer with label notification (Time-Keeper)
const std = @import("std");
const ollama = @import("ollama");
const permission = @import("permission");
const context_module = @import("context");
const tools_module = @import("../tools.zig");
const state_module = @import("state");

const AppContext = context_module.AppContext;
const ToolDefinition = tools_module.ToolDefinition;
const ToolResult = tools_module.ToolResult;

/// Context passed to timer thread (heap-allocated, owned by thread)
const TimerThreadContext = struct {
    allocator: std.mem.Allocator,
    state: *state_module.AppState,
    label: []const u8, // owned copy
    duration_ms: u64,

    fn deinit(self: *TimerThreadContext) void {
        self.allocator.free(self.label);
        self.allocator.destroy(self);
    }
};

pub fn getDefinition(allocator: std.mem.Allocator) !ToolDefinition {
    return .{
        .ollama_tool = .{
            .type = "function",
            .function = .{
                .name = try allocator.dupe(u8, "set_timer"),
                .description = try allocator.dupe(u8,
                    \\Set a fire-and-forget timer. When the timer expires, a system message
                    \\will be injected into the conversation with your label. Use descriptive
                    \\labels like "check_breakfast_order" or "follow_up_delivery_status".
                    \\Duration is in seconds. Example: {"duration_seconds": 30, "label": "check_order"}
                ),
                .parameters = try allocator.dupe(u8,
                    \\{
                    \\  "type": "object",
                    \\  "properties": {
                    \\    "duration_seconds": {
                    \\      "type": "number",
                    \\      "description": "Timer duration in seconds (e.g., 30, 60, 300)"
                    \\    },
                    \\    "label": {
                    \\      "type": "string",
                    \\      "description": "Descriptive label for the timer reminder"
                    \\    }
                    \\  },
                    \\  "required": ["duration_seconds", "label"]
                    \\}
                ),
            },
        },
        .permission_metadata = .{
            .name = "set_timer",
            .description = "Set a fire-and-forget timer with notification",
            .risk_level = .safe, // No external effects, just internal timing
            .required_scopes = &.{.system_info},
            .validator = null,
        },
        .execute = execute,
    };
}

/// Timer thread function - sleeps then adds notification to queue
fn timerThreadFn(ctx: *TimerThreadContext) void {
    // Sleep for the specified duration
    const duration_ns = ctx.duration_ms * std.time.ns_per_ms;
    std.Thread.sleep(duration_ns);

    // Add notification to queue (thread-safe)
    ctx.state.addTimerNotification(ctx.label, ctx.duration_ms) catch |err| {
        // Log error but don't crash - timer simply won't notify
        std.debug.print("[TIMER] Failed to add notification for '{s}': {}\n", .{ ctx.label, err });
    };

    // Clean up thread context
    ctx.deinit();
}

fn execute(allocator: std.mem.Allocator, arguments: []const u8, context: *AppContext) !ToolResult {
    const start_time = std.time.milliTimestamp();

    // Parse arguments
    const Args = struct {
        duration_seconds: f64, // Use f64 to accept decimal seconds like 1.5
        label: []const u8,
    };

    const parsed = std.json.parseFromSlice(Args, allocator, arguments, .{}) catch {
        return ToolResult.err(
            allocator,
            .parse_error,
            "Invalid JSON arguments. Expected: {\"duration_seconds\": 30, \"label\": \"...\"}",
            start_time,
        );
    };
    defer parsed.deinit();

    // Validate duration
    if (parsed.value.duration_seconds <= 0) {
        return ToolResult.err(
            allocator,
            .invalid_input,
            "duration_seconds must be positive",
            start_time,
        );
    }

    // Validate label
    if (parsed.value.label.len == 0) {
        return ToolResult.err(
            allocator,
            .invalid_input,
            "label cannot be empty",
            start_time,
        );
    }

    if (parsed.value.label.len > 256) {
        return ToolResult.err(
            allocator,
            .invalid_input,
            "label must be 256 characters or less",
            start_time,
        );
    }

    // Convert to milliseconds
    const duration_ms: u64 = @intFromFloat(parsed.value.duration_seconds * 1000.0);

    // Create thread context (heap-allocated, owned by timer thread)
    const thread_ctx = try allocator.create(TimerThreadContext);
    errdefer allocator.destroy(thread_ctx);

    thread_ctx.* = .{
        .allocator = allocator,
        .state = context.state,
        .label = try allocator.dupe(u8, parsed.value.label),
        .duration_ms = duration_ms,
    };

    // Spawn timer thread (fire-and-forget)
    const thread = std.Thread.spawn(.{}, timerThreadFn, .{thread_ctx}) catch |err| {
        thread_ctx.deinit();
        const msg = try std.fmt.allocPrint(allocator, "Failed to spawn timer thread: {}", .{err});
        defer allocator.free(msg);
        return ToolResult.err(allocator, .internal_error, msg, start_time);
    };

    // Detach thread - we don't need to join it
    thread.detach();

    // Return success
    const result_msg = try std.fmt.allocPrint(
        allocator,
        "{{\"status\": \"timer_set\", \"label\": \"{s}\", \"duration_seconds\": {d:.1}}}",
        .{ parsed.value.label, parsed.value.duration_seconds },
    );
    defer allocator.free(result_msg);

    return ToolResult.ok(allocator, result_msg, start_time, null);
}
