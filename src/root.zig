const std = @import("std");

const libs = struct {
    usingnamespace @import("channels.zig");
    usingnamespace @import("consumers.zig");
    usingnamespace @import("actors.zig");
};

pub const Receipt = libs.Receipt;
pub const ChannelWriter = libs.ChannelWriter;
pub const ChannelReader = libs.ChannelReader;
pub const SimpleChannel = libs.SimpleChannel;
pub const ChannelError = libs.ChannelError;

pub const ChannelConsumer = libs.ChannelConsumer;
pub const HandlerFn = libs.HandlerFn;

pub const Actor = libs.Actor;

test {
    std.testing.refAllDecls(@This());
}
