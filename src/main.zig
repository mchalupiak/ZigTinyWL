const std = @import("std");

const wlr = @import("wlroots");
const way = @import("wayland");
const wl = way.server.wl;
const xdg = way.server.xdg;
const ext = way.server.ext;

const c = @cImport({
    @cDefine("_POSIX_C_SOURCE", "200809L");

    @cInclude("stdlib.h");
    @cInclude("unistd.h");

    @cInclude("linux/input-event-codes.h");
    @cInclude("libevdev/libevdev.h");

    @cInclude("libinput.h");
});

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn new_output_notify(listener: *wl.Listener(*wlr.Output), wlr_output: *wlr.Output) void {
    // const output = alloc.alloc(wlr.Output);
    // const server: *zwl_server = @fieldParentPtr("new_output", listener);
    // _ = wlr_output.initRender(server.allocator, server.renderer);
    // _ = output;
    _ = listener;
    _ = wlr_output;
}

const zwl_server = struct {
    wl_display: *wl.Server,
    wl_eventloop: *wl.EventLoop,

    backend: *wlr.Backend,
    renderer: *wlr.Renderer,

    allocator: *wlr.Allocator,

    new_output: wl.Listener(*wlr.Output),
    outputs: wl.list.Head(wlr.Output, .all_link),

    pub fn init() !@This() {
        const display = try wl.Server.create();
        const event_loop = display.getEventLoop();

        var session: ?*wlr.Session = undefined;
        const backend = try wlr.Backend.autocreate(event_loop, &session);
        const renderer = try wlr.Renderer.autocreate(backend);
        var outputs: wl.list.Head(wlr.Output, .all_link) = undefined;
        outputs.init();
        var new_output = wl.Listener(*wlr.Output).init(new_output_notify);

        backend.events.new_output.add(&new_output);

        try renderer.initServer(display);
        return .{
            .wl_display = display,
            .wl_eventloop = event_loop,
            .backend = backend,
            .renderer = renderer,
            .allocator = try wlr.Allocator.autocreate(backend, renderer),
            .new_output = new_output,
            .outputs = outputs,
        };
    }

    pub fn start(zwl: zwl_server) !void {
        var buf: [11]u8 = undefined;
        const socket = try zwl.wl_display.addSocketAuto(&buf);
        zwl.backend.start() catch {
            std.debug.print("Failed to start backend\n", .{});
            zwl.wl_display.destroy();
            return;
        };

        if (c.setenv("WAYLAND_DISPLAY", socket.ptr, 1) < 0) return error.SetenvError;
        zwl.wl_display.run();
        zwl.wl_display.destroy();
    }
};

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    const server = try zwl_server.init();
    try server.start();
}
