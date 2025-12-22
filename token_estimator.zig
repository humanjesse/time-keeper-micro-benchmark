// Token estimation for sliding context window (Time-Keeper)
// Uses simple chars/4 heuristic - can be enhanced later with actual tokenizer

const std = @import("std");
const types = @import("types");

/// Estimated tokens for tool definitions (16 tools with JSON schemas)
/// 7800 chars / 4 = ~1950, rounded up to 2000 for safety
pub const TOOL_DEFINITIONS_OVERHEAD: usize = 2000;

/// Calculate effective message budget accounting for tool overhead
pub fn effectiveBudget(num_ctx: usize) usize {
    if (num_ctx <= TOOL_DEFINITIONS_OVERHEAD) return 0;
    return num_ctx - TOOL_DEFINITIONS_OVERHEAD;
}

/// Estimate token count for a string using chars/4 heuristic
/// Conservative estimate for English text with code
pub fn estimateTokens(text: []const u8) usize {
    return (text.len + 3) / 4; // Round up
}

/// Estimate tokens for a single Message struct
/// Includes content, thinking, tool calls, and framing overhead
pub fn estimateMessageTokens(msg: *const types.Message) usize {
    var total: usize = 0;

    // Main content
    total += estimateTokens(msg.content);

    // Thinking content if present
    if (msg.thinking_content) |thinking| {
        total += estimateTokens(thinking);
    }

    // Tool calls metadata (assistant messages that call tools)
    if (msg.tool_calls) |calls| {
        for (calls) |call| {
            total += estimateTokens(call.function.name);
            total += estimateTokens(call.function.arguments);
            if (call.id) |id| total += estimateTokens(id);
        }
    }

    // Tool call ID (for tool response messages)
    if (msg.tool_call_id) |id| {
        total += estimateTokens(id);
    }

    // Role/message framing overhead (~5 tokens)
    total += 5;

    return total;
}

/// Result of pruning calculation
pub const PruneInfo = struct {
    total_estimated: usize,
    prune_count: usize,
};

/// Calculate how many messages to prune to fit within token budget
/// Preserves message at index 0 (system prompt), prunes oldest messages first
pub fn calculatePruning(
    messages: []const types.Message,
    budget: usize,
) PruneInfo {
    // Calculate total tokens
    var total: usize = 0;
    for (messages) |*msg| {
        if (msg.role == .display_only_data) continue;
        total += estimateMessageTokens(msg);
    }

    // Under budget - no pruning needed
    if (total <= budget) {
        return .{ .total_estimated = total, .prune_count = 0 };
    }

    // Over budget - calculate how many to prune
    var running = total;
    var prune_count: usize = 0;
    var i: usize = 1; // Start at 1 to skip system message at index 0

    while (i < messages.len and running > budget) : (i += 1) {
        const msg = &messages[i];
        if (msg.role == .display_only_data) continue;
        running -= estimateMessageTokens(msg);
        prune_count += 1;
    }

    return .{ .total_estimated = total, .prune_count = prune_count };
}

// Tests
test "estimateTokens basic" {
    // 4 chars = 1 token
    try std.testing.expectEqual(@as(usize, 1), estimateTokens("test"));
    try std.testing.expectEqual(@as(usize, 3), estimateTokens("hello world"));
    try std.testing.expectEqual(@as(usize, 0), estimateTokens(""));
}

test "estimateTokens rounding" {
    // 5 chars rounds up to 2 tokens
    try std.testing.expectEqual(@as(usize, 2), estimateTokens("12345"));
    // 8 chars = 2 tokens
    try std.testing.expectEqual(@as(usize, 2), estimateTokens("12345678"));
}
