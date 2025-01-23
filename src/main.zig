const std = @import("std");

const wlr = @import("wlroots");
const way = @import("wayland");
const wl = way.server.wl;
const xdg = way.server.xdg;
const ext = way.server.ext;

fn new_output_notify(listener: *wl.Listener(*wlr.Output), data: *wlr.Output) void {
    _ = listener;
    _ = data;
}

const zwl_server = struct {
    wl_display: *wl.Server,
    wl_eventloop: *wl.EventLoop,

    backend: *wlr.Backend,

    new_output: wl.Listener(*wlr.Output),
    outputs: wl.list.Head(wlr.Output, .all_link),

    pub fn init() !@This() {
        const display = try wl.Server.create();
        const event_loop = display.getEventLoop();
        const backend = try wlr.Backend.autocreate(event_loop, null);
        var outputs: wl.list.Head(wlr.Output, .all_link) = undefined;
        outputs.init();
        var new_output = wl.Listener(*wlr.Output).init(new_output_notify);
        backend.events.new_output.add(&new_output);
        return .{
            .wl_display = display,
            .wl_eventloop = event_loop,
            .backend = backend,
            .new_output = new_output,
            .outputs = outputs,
        };
    }

    pub fn start(zwl: zwl_server) void {
        zwl.backend.start() catch {
            zwl.wl_display.destroy();
            return;
        };

        zwl.wl_display.run();
        zwl.wl_display.destroy();
    }
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const server = try zwl_server.init();
    server.start();
}
