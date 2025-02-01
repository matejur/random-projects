const std = @import("std");
const rl = @import("raylib");

const print = std.debug.print;
const ArrayList = std.ArrayList;

const CELL_SIZE = 64;
const HEIGHT = CELL_SIZE * 10;
const WIDTH = CELL_SIZE * 10;

const UP = 0;
const RIGHT = 1;
const DOWN = 2;
const LEFT = 3;

var prng = std.rand.DefaultPrng.init(0);
const rand = prng.random();

fn imagesEqual(img1: rl.Image, img2: rl.Image) bool {
    const size: usize = @intCast(img1.width * img1.height * 4);
    const pix1 = @as([*]u8, @ptrCast(img1.data))[0..size];
    const pix2 = @as([*]u8, @ptrCast(img2.data))[0..size];

    return std.mem.eql(u8, pix1, pix2);
}

fn addIfUnique(img: rl.Image, unique_images: *ArrayList(rl.Image)) !void {
    for (unique_images.items) |unique| {
        if (imagesEqual(img, unique)) {
            img.unload();
            return;
        }
    }

    try unique_images.append(img);
}

const Tile = struct {
    texture: rl.Texture,
    edges: [4][]usize,
    neighbors: [4]ArrayList(Tile),

    fn tiles_from_img(path: [*:0]const u8, alloc: std.mem.Allocator) !ArrayList(Tile) {
        var image = try rl.loadImage(path);
        defer image.unload();

        const width: usize = @intCast(image.width);
        const height: usize = @intCast(image.height);

        if (width != height) return error.TileNotSquare;

        var unique_images = ArrayList(rl.Image).init(alloc);
        defer unique_images.deinit();

        for (0..4) |_| {
            const imgCopy = image.copy();
            var imgCopyFlip = image.copy();
            imgCopyFlip.flipHorizontal();

            try addIfUnique(imgCopy, &unique_images);
            try addIfUnique(imgCopyFlip, &unique_images);

            image.rotateCW();
        }

        var tiles = ArrayList(Tile).init(alloc);

        for (unique_images.items) |img| {
            try tiles.append(try Tile.init(@constCast(&img), alloc));
        }

        return tiles;
    }

    pub fn init(img: *rl.Image, alloc: std.mem.Allocator) !Tile {
        const width: usize = @intCast(img.width);
        const height: usize = @intCast(img.height);

        if (width != height) return error.TileNotSquare;

        var edges = [4][]usize{
            try alloc.alloc(usize, width),
            try alloc.alloc(usize, width),
            try alloc.alloc(usize, width),
            try alloc.alloc(usize, width),
        };

        const pixels = try rl.loadImageColors(img.*);
        for (0..height) |y| {
            for (0..width) |x| {
                const pixel = pixels[x + width * y];
                const value: usize = @as(usize, pixel.r) * 255 * 255 + @as(usize, pixel.g) * 255 + @as(usize, pixel.b);
                if (y == 0) {
                    edges[UP][x] = value;
                }
                if (x == width - 1) {
                    edges[RIGHT][y] = value;
                }
                if (y == height - 1) {
                    edges[DOWN][x] = value;
                }
                if (x == 0) {
                    edges[LEFT][y] = value;
                }
            }
        }

        const neighbors = [4]ArrayList(Tile){
            ArrayList(Tile).init(alloc),
            ArrayList(Tile).init(alloc),
            ArrayList(Tile).init(alloc),
            ArrayList(Tile).init(alloc),
        };

        img.resizeNN(CELL_SIZE, CELL_SIZE);
        defer img.unload();

        return Tile{
            .edges = edges,
            .texture = try img.toTexture(),
            .neighbors = neighbors,
        };
    }

    fn addNeighbors(self: *Tile, other: ArrayList(Tile)) !void {
        for (other.items) |o| {
            const e1 = self.edges;
            const e2 = o.edges;
            if (std.mem.eql(usize, e1[UP], e2[DOWN])) try self.neighbors[UP].append(o);
            if (std.mem.eql(usize, e1[RIGHT], e2[LEFT])) try self.neighbors[RIGHT].append(o);
            if (std.mem.eql(usize, e1[DOWN], e2[UP])) try self.neighbors[DOWN].append(o);
            if (std.mem.eql(usize, e1[LEFT], e2[RIGHT])) try self.neighbors[LEFT].append(o);
        }
    }

    pub fn deinit(self: *Tile, alloc: std.mem.Allocator) void {
        self.texture.unload();

        for (self.neighbors) |neigh| {
            neigh.deinit();
        }

        for (self.edges) |edge| {
            alloc.free(edge);
        }
    }
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    rl.initWindow(WIDTH, HEIGHT, "Wave function collapse");
    defer rl.closeWindow();

    var tiles = ArrayList(Tile).init(alloc);
    defer {
        for (tiles.items) |*tile| tile.deinit(alloc);
        tiles.deinit();
    }

    var assets_dir = try std.fs.cwd().openDir("assets", .{ .iterate = true });
    var iter = assets_dir.iterate();

    while (try iter.next()) |file| {
        const path = try std.fmt.allocPrintZ(alloc, "assets/{s}", .{file.name});
        const temp = try Tile.tiles_from_img(path, alloc);
        try tiles.appendSlice(temp.items);
        temp.deinit();
    }

    for (tiles.items) |*t1| {
        try t1.addNeighbors(tiles);
    }

    const t1 = tiles.getLast();

    rl.setTargetFPS(10);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        var x: i32 = 0;
        var y: i32 = 0;
        for (tiles.items) |tile| {
            rl.drawTexture(tile.texture, x * CELL_SIZE, y * CELL_SIZE, rl.Color.white);

            x += 1;
            if (x == 10) {
                x = 0;
                y += 1;
            }
        }

        x = 5;
        y = 5;
        rl.drawTexture(t1.texture, x * CELL_SIZE, y * CELL_SIZE, rl.Color.white);

        const neigh_idx = rand.intRangeLessThan(usize, 0, t1.neighbors[UP].items.len);
        const t2 = t1.neighbors[UP].items[neigh_idx];
        y -= 1;
        rl.drawTexture(t2.texture, x * CELL_SIZE, y * CELL_SIZE, rl.Color.white);
    }
}
