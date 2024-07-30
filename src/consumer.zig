const std = @import("std");

const ChannelReader = @import("./channel_interface.zig").ChannelReader;

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
        pub fn run(self: *@This()) !std.Thread {
            return std.Thread.spawn(.{}, consume, .{&self});
        }
        fn consume(self: *@This()) void {
            while (true) {
                const msg = self.channel.popOrNull() orelse continue;
                self.handler(msg);
            }
        }
    };
}
