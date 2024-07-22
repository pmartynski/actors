const std = @import("std");
const testing = std.testing;

const channel_interface = @import("channel_interface.zig");
pub const Receipt = channel_interface.Receipt;
pub const ChannelProducer = channel_interface.ChannelProducer;

const simple_channel = @import("simple_channel.zig");
pub const SimpleChannel = simple_channel.SimpleChannel;
pub const ChannelError = simple_channel.ChannelError;

test {
    testing.refAllDecls(@This());
}
