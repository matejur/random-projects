const std = @import("std");
const rl = @import("raylib");
const QTree = @import("qtree.zig").QTree;

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

    var tree = QTree(Point).init(0, 0, WIDTH, HEIGHT, alloc);
    print("{}\n", .{tree.items.len});

    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    rl.initWindow(WIDTH, HEIGHT, "Wave function collapse");
    rl.setWindowPosition(3500, 200);
    defer rl.closeWindow();

    rl.setTargetFPS(30);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            const pt = try alloc.create(Point);
            pt.* = .{
                .x = rl.getMouseX(),
                .y = rl.getMouseY(),
            };

            try tree.add(pt);
        }

        tree.draw();
    }
}
