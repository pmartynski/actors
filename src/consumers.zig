const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// TODO: docs
const libs = struct {
    usingnamespace @import("channels.zig");
};

pub fn HandlerFn(comptime T: type, comptime S: type) type {
    return *const fn (msg: *const T, state: *S) void;
}

pub fn ChannelConsumer(comptime T: type, comptime S: type) type {
    return struct {
        channel: libs.ChannelReader(T),
        handler: HandlerFn(T, S),
        state: *S,
        pub fn create(channel: libs.ChannelReader(T), handler: HandlerFn(T, S), init_state: *S) @This() {
            return .{
                .channel = channel,
                .handler = handler,
                .state = init_state,
            };
        }

        pub fn close(self: *@This()) void {
            self.channel.close();
        }

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
