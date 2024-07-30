const std = @import("std");
const builtin = @import("builtin");

const ChannelReader = @import("./channel_interface.zig").ChannelReader;

// TODO add state param to support actor states
pub fn HandlerFn(comptime T: type) type {
    return *const fn (msg: *const T) void;
}

pub fn ChannelConsumer(comptime T: type) type {
    return struct {
        channel: ChannelReader(T),
        handler: HandlerFn(T),
        pub fn create(channel: ChannelReader(T), handler: HandlerFn(T)) ChannelConsumer(T) {
            return .{
                .channel = channel,
                .handler = handler,
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
                if (builtin.is_test) {
                    std.time.sleep(10 * std.time.ns_per_ms);
                }

                const msg = self.channel.popOrNull() orelse {
                    if (self.channel.isOpen()) continue else break;
                };
                self.handler(msg);
            }
        }
    };
}

const SimpleChannel = @import("simple_channel.zig").SimpleChannel(u8, 10);
const testing = std.testing;

test "INT consumer should be able to drain the channel" {
    var ch = try SimpleChannel.init(testing.allocator);
    defer ch.deinit();

    const Handler = struct {
        pub var n: u8 = 0;
        pub fn handler(msg: *const u8) void {
            @This().n += 1;
            _ = msg;
        }
    };
    var consumer = ChannelConsumer(u8).create(
        ch.channelReader(),
        Handler.handler,
    );

    var t = try consumer.run();
    for (0..10) |value| {
        _ = try ch.send(@intCast(value));
    }
    consumer.close();
    t.join();

    try testing.expectEqual(0, ch.size());
    try testing.expectEqual(10, Handler.n);
}
