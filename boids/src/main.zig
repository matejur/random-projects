const std = @import("std");
const rl = @import("raylib");
const quadtree = @import("quadtree");
const shapes = quadtree.shapes;
const QTree = quadtree.QTree;
const Boid = @import("boid.zig").Boid;

const WIDTH = 1200;
const HEIGHT = 1200;
const MARGIN = 150;

const VISUAL_RANGE = 100;
const PROTECTED_RANGE = 20;

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

    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    rl.initWindow(WIDTH, HEIGHT, "Boids");
    rl.setWindowPosition(3500, 200);
    defer rl.closeWindow();

    var boids: [300]Boid = undefined;
    for (&boids) |*boid| {
        boid.* = Boid{
            .x = rand.intRangeLessThan(i32, 0, WIDTH),
            .y = rand.intRangeLessThan(i32, 0, HEIGHT),
            .vx = rand.float(f32) * 4 - 2,
            .vy = rand.float(f32) * 4 - 2,
        };
    }

    var tree = QTree(Boid, 3).init(
        .{
            .x = 0,
            .y = 0,
            .width = WIDTH,
            .height = HEIGHT,
        },
        alloc,
    );

    rl.setTargetFPS(30);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        // add boids to tree
        for (&boids) |*boid| {
            try tree.add(boid);
        }
        // tree.draw();

        var others = std.ArrayList(*const Boid).init(alloc);
        for (&boids) |*boid| {
            try tree.queryXYR(boid.x, boid.y, PROTECTED_RANGE, &others);
            boid.separate(others.items);
            others.clearRetainingCapacity();

            try tree.queryXYR(boid.x, boid.y, VISUAL_RANGE, &others);
            boid.cohesion(others.items);
            boid.alignment(others.items);
            others.clearRetainingCapacity();

            boid.avoidEdges(MARGIN, MARGIN, WIDTH - MARGIN, HEIGHT - MARGIN);
            boid.constrainSpeed();
        }

        for (&boids) |*boid| {
            boid.update();
            boid.draw();
        }

        tree.clear();
        _ = arena.reset(std.heap.ArenaAllocator.ResetMode.retain_capacity);
    }
}
