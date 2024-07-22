const std = @import("std");
const testing = std.testing;

const channel_interface = @import("channel_interface.zig");
pub const Receipt = channel_interface.Receipt;
pub const ChannelWriter = channel_interface.ChannelWriter;
pub const ChannelReader = channel_interface.ChannelReader;

const simple_channel = @import("simple_channel.zig");
pub const SimpleChannel = simple_channel.SimpleChannel;
pub const ChannelError = simple_channel.ChannelError;

test {
    testing.refAllDecls(@This());
}
