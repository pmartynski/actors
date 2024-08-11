const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const libs = struct {
    usingnamespace @import("channels.zig");
};

/// Defines a handler function type for consuming messages of type `T` with state of type `S`.
pub fn HandlerFn(comptime T: type, comptime S: type) type {
    return *const fn (msg: *const T, state: *S) void;
}

/// Creates a ChannelConsumer for consuming messages from a channel.
///
/// # Parameters
/// - `T`: The type of messages in the channel.
/// - `S`: The type of the internal state.
///
/// The `ChannelConsumer` struct represents a consumer that reads messages from a channel and
/// processes them using a handler function. It maintains an internal state that can be accessed
/// and modified by the handler function.
///
/// Example usage:
/// ```zig
/// const consumer = ChannelConsumer(u8, MyState).create(channel, handler, &state);
/// const thread = try consumer.run();
/// // ...
/// consumer.close();
/// thread.join();
/// ```
pub fn ChannelConsumer(comptime T: type, comptime S: type) type {
    return struct {
        channel: libs.ChannelReader(T),
        handler: HandlerFn(T, S),
        state: *S,

        /// Creates a new consumer with the specified channel, handler function, and initial state.
        ///
        /// # Parameters
        /// - `channel`: The channel to read messages from.
        /// - `handler`: The function that will handle the messages.
        /// - `init_state`: A pointer to the initial state of the consumer.
        ///
        /// # Returns
        /// A new consumer instance.
        pub fn create(channel: libs.ChannelReader(T), handler: HandlerFn(T, S), init_state: *S) @This() {
            return .{
                .channel = channel,
                .handler = handler,
                .state = init_state,
            };
        }

        /// Closes the consumer.
        ///
        /// This function closes the consumer by closing the associated channel.
        pub fn close(self: *@This()) void {
            self.channel.close();
        }

        /// Spawns a consumer thread.
        ///
        /// Returns the newly spawned thread.
        pub fn run(self: *@This()) !std.Thread {
            return std.Thread.spawn(.{}, consume, .{self});
        }

        fn consume(self: *@This()) void {
            while (true) {
                const msg = self.channel.popOrNull() orelse {
                    if (self.channel.isOpen()) continue else break;
                };

                if (builtin.is_test) {
                    std.time.sleep(1 * std.time.ns_per_ms);
                }

                self.handler(msg, self.*.state);
            }
        }
    };
}

test "INT consumer should be able to drain the channel" {
    var ch = try libs.SimpleChannel(u8, 10).init(testing.allocator);
    defer ch.deinit();

    const State = struct {
        n: u8,
        pub fn handler(msg: *const u8, state: *@This()) void {
            _ = msg;
            state.*.n += 1;
        }
    };
    var state = State{ .n = 0 };
    var consumer = ChannelConsumer(u8, State).create(
        ch.channelReader(),
        State.handler,
        &state,
    );

    var t = try consumer.run();
    for (0..10) |value| {
        _ = try ch.send(@intCast(value));
    }
    consumer.close();
    t.join();

    try testing.expectEqual(0, ch.size());
    try testing.expectEqual(10, state.n);
}
