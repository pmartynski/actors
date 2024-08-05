const std = @import("std");
const testing = std.testing;

const c = @import("consumers.zig");
const s = @import("channels.zig");

/// An actor consists of an inbox channel, a consumer. The inbox channel allows sending messages to the actor.
/// The consumer processes the incoming messages using a handler function and updates the state accordingly.
/// An Actor is guarantied to be single-threaded.
///
/// Example:
/// ```
///
/// const MyState = struct { sum: u32 };
///
/// fn handle(msg: *const u32, state: *MyState) void {
///     state.*.sum += msg.*;
/// }
///
/// pub fn main() void {
///   const initialState = &MyState { sum = 0 };
///   var a = try Actor(MyState, u32).init(
///       allocator,
///       initialState,
///       handle,
///   );
///   defer a.deinit();
///   try a.run();
///
///   const inbox = a.inbox();
///   _ = try inbox.send(1);
/// }
/// ```
pub fn Actor(comptime S: type, comptime T: type) type {
    return struct {
        state: *S,
        inboxChannel: *s.SimpleChannel(T, 128),
        consumer: c.ChannelConsumer(T, S),
        thread: ?std.Thread,
        allocator: std.mem.Allocator,

        /// Returns a channel writer for sending messages to the actor's inbox.
        pub fn inbox(self: *@This()) s.ChannelWriter(T) {
            return self.*.inboxChannel.channelWriter();
        }

        /// Initializes an actor with the specified state type `S`, message type `T`, and handler function.
        ///
        /// The `allocator` parameter is used to allocate memory for the actor's inbox channel and state.
        /// The `init_state` parameter is a pointer to the initial state of the actor.
        /// The `handler` parameter is a function that processes incoming messages and updates the state accordingly.
        pub fn init(
            allocator: std.mem.Allocator,
            init_state: *S,
            handler: c.HandlerFn(T, S),
        ) !@This() {
            const channel = try allocator.create(s.SimpleChannel(T, 128));
            channel.* = try s.SimpleChannel(T, 128).init(allocator);
            const consumer = c.ChannelConsumer(T, S).create(
                channel.*.channelReader(),
                handler,
                init_state,
            );
            return @This(){
                .allocator = allocator,
                .inboxChannel = channel,
                .consumer = consumer,
                .state = init_state,
                .thread = null,
            };
        }

        /// Starts the consumer thread
        pub fn run(self: *@This()) !void {
            self.*.thread = try self.*.consumer.run();
        }

        /// Clears the allocated memory
        pub fn deinit(self: *@This()) void {
            self.inboxChannel.deinit();
            self.allocator.destroy(self.inboxChannel);

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
    var a = try Actor(State, Msg).init(
        testing.allocator,
        initialState,
        H.handle,
    );
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
