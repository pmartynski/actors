# Zig Actors

This is a simple actor system for Zig. Actor model is a way of organizing concurrent programs. It is based on the idea of actors, which are independent units of computation that communicate by sending messages to each other. This model is a good fit for many kinds of applications, such as network servers, GUI applications, and simulations.

The current implementation is very basic and has some limitations. It is a work in progress and I plan to improve it over time. Here are some of the limitations:

- Actors are not automatically scheduled. You have to call `Actor.run` to run an actor.
- There is no support for actor supervision.
- Actors can only send messages to other actors. There is no support for sending messages to non-actor objects.
- Actors can only send messages to one other actor at a time. There is no support for broadcasting messages to multiple actors.
- There is no support for actor discovery. You have to manually keep track of actor references.
- There is no support for remote actors. All actors must run in the same process.

Despite these limitations, I think this actor system is a good starting point for building more complex systems. I hope you find it useful!
