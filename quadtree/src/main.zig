const std = @import("std");
const rl = @import("raylib");
const QTree = @import("qtree.zig").QTree;
const shapes = @import("shapes.zig");

const Rectangle = shapes.Rectangle;
const Circle = shapes.Circle;

const print = std.debug.print;

const WIDTH = 800;
const HEIGHT = 800;

const Point = struct {
    x: i32,
    y: i32,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();
    defer arena.deinit();

    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var tree = QTree(Point, 3).init(
        .{
            .x = 0,
            .y = 0,
            .width = WIDTH,
            .height = HEIGHT,
        },
        alloc,
    );

    for (0..1000) |_| {
        const pt: *Point = try alloc.create(Point);
        pt.* = .{
            .x = rand.intRangeLessThan(i32, 0, WIDTH),
            .y = rand.intRangeLessThan(i32, 0, HEIGHT),
        };

        try tree.add(pt);
    }

    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    rl.initWindow(WIDTH, HEIGHT, "Wave function collapse");
    rl.setWindowPosition(3500, 200);
    defer rl.closeWindow();

    rl.setTargetFPS(30);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        const circ = Circle{
            .x = rl.getMouseX(),
            .y = rl.getMouseY(),
            .r = 100,
        };

        var inside = std.ArrayList(*const Point).init(alloc);
        defer inside.deinit();

        try tree.query(circ, &inside);
        tree.draw();
        circ.draw();

        for (inside.items) |pt| {
            rl.drawCircle(pt.x, pt.y, 5, rl.Color.blue);
        }
    }
}
