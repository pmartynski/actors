const std = @import("std");
const testing = std.testing;

const c = @import("consumer.zig");
const s = @import("simple_channel.zig");

pub fn Actor(comptime S: type, comptime T: type) type {
    return struct {
        state: *S,
        channel: *s.SimpleChannel(T, 128),
        consumer: c.ChannelConsumer(T, S),
        thread: ?std.Thread,
        allocator: std.mem.Allocator,

        pub fn inbox(self: *@This()) s.ChannelWriter(T) {
            return self.*.channel.channelWriter();
        }

        pub fn init(allocator: std.mem.Allocator, init_state: *S, handler: c.HandlerFn(T, S)) !@This() {
            const channel = try allocator.create(s.SimpleChannel(T, 128));
            channel.* = try s.SimpleChannel(T, 128).init(allocator);
            const consumer = c.ChannelConsumer(T, S).create(
                channel.*.channelReader(),
                handler,
                init_state,
            );
            return @This(){
                .channel = channel,
                .consumer = consumer,
                .state = init_state,
                .thread = null,
                .allocator = allocator,
            };
        }

        pub fn run(self: *@This()) !void {
            self.*.thread = try self.*.consumer.run();
        }

        pub fn deinit(self: *@This()) void {
            self.channel.deinit();
            self.allocator.destroy(self.channel);

            const ts = @typeInfo(S);

            if (ts == .Struct and @hasDecl(S, "deinit")) {
                self.*.state.*.deinit();
            }

            switch (ts) {
                .Array => self.*.allocator.free(self.*.state),
                else => self.*.allocator.destroy(self.*.state),
            }
        }
    };
}

test "INT actor" {
    const Msg = struct { u8, u8 };
    const State = std.AutoHashMap(u8, u8);
    const H = struct {
        pub fn handle(msg: *const Msg, state: *State) void {
            state.put(msg.*.@"0", msg.*.@"1") catch {
                std.log.err("Put failed", .{});
                return;
            };
        }
    };

    const initialState = try testing.allocator.create(State);
    initialState.* = State.init(testing.allocator);
    var a = try Actor(State, Msg).init(testing.allocator, initialState, H.handle);
    defer a.deinit();
    try a.run();

    const inbox = a.inbox();
    _ = try inbox.send(.{ 0, 1 });
    _ = try inbox.send(.{ 1, 2 });
    _ = try inbox.send(.{ 2, 4 });
    _ = try inbox.send(.{ 4, 16 });

    std.time.sleep(std.time.ns_per_s);

    const actual = initialState.*.get(4);
    try testing.expectEqual(16, actual);
}
