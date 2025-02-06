const std = @import("std");
const rl = @import("raylib");

const print = std.debug.print;
const ArrayList = std.ArrayList;

const CELL_SIZE = 32;
const ROWS = 20;
const COLUMNS = 40;

const HEIGHT = CELL_SIZE * ROWS;
const WIDTH = CELL_SIZE * COLUMNS;

const UP = 0;
const RIGHT = 1;
const DOWN = 2;
const LEFT = 3;

fn imagesEqual(img1: rl.Image, img2: rl.Image) bool {
    const size: usize = @intCast(img1.width * img1.height * 4);
    const pix1 = @as([*]u8, @ptrCast(img1.data))[0..size];
    const pix2 = @as([*]u8, @ptrCast(img2.data))[0..size];

    return std.mem.eql(u8, pix1, pix2);
}

fn addIfUnique(img: rl.Image, unique_images: *ArrayList(rl.Image)) !bool {
    for (unique_images.items) |unique| {
        if (imagesEqual(img, unique)) return false;
    }

    try unique_images.append(img);
    return true;
}

const Tile = struct {
    texture: rl.Texture,
    edges: [4][]usize,
    neighbors: [4]ArrayList(*Tile),

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

            if (!try addIfUnique(imgCopy, &unique_images)) imgCopy.unload();
            if (!try addIfUnique(imgCopyFlip, &unique_images)) imgCopyFlip.unload();

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

        const neighbors = [4]ArrayList(*Tile){
            ArrayList(*Tile).init(alloc),
            ArrayList(*Tile).init(alloc),
            ArrayList(*Tile).init(alloc),
            ArrayList(*Tile).init(alloc),
        };

        img.resizeNN(CELL_SIZE, CELL_SIZE);
        defer img.unload();

        return Tile{
            .texture = try img.toTexture(),
            .edges = edges,
            .neighbors = neighbors,
        };
    }

    fn addNeighbors(self: *Tile, other: ArrayList(Tile)) !void {
        for (other.items) |*o| {
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

const Cell = struct {
    x: i32,
    y: i32,
    possible_tiles: ArrayList(*Tile),
    collapsed_tile: ?*Tile,

    fn init(x: i32, y: i32, tiles: ArrayList(*Tile)) Cell {
        return Cell{
            .x = x,
            .y = y,
            .possible_tiles = tiles,
            .collapsed_tile = null,
        };
    }

    fn draw(self: Cell) void {
        const draw_x = self.x * CELL_SIZE;
        const draw_y = self.y * CELL_SIZE;
        if (self.collapsed_tile) |tile| {
            rl.drawTexture(tile.texture, draw_x, draw_y, rl.Color.white);
            return;
        }

        const color = if (self.possible_tiles.items.len == 0) rl.Color.red else rl.Color.white;
        rl.drawRectangle(
            draw_x + 1,
            draw_y + 1,
            CELL_SIZE - 2,
            CELL_SIZE - 2,
            color,
        );

        const text_size = 24;
        rl.drawText(
            rl.textFormat("%d", .{self.possible_tiles.items.len}),
            draw_x + CELL_SIZE / 2 - text_size / 2,
            draw_y + CELL_SIZE / 2 - text_size / 2,
            text_size,
            rl.Color.black,
        );
    }

    fn reduceOptions(self: *Cell, tile: *Tile, dir: comptime_int) void {
        var index = self.possible_tiles.items.len;
        while (index > 0) : (index -= 1) {
            const pos = self.possible_tiles.items[index - 1];
            var is_possible = false;
            for (tile.neighbors[dir].items) |neig| {
                if (neig == pos) {
                    is_possible = true;
                    break;
                }
            }

            if (!is_possible) {
                _ = self.possible_tiles.swapRemove(index - 1);
            }
        }
    }
};

const Wave = struct {
    cells: []Cell,

    fn init(cells: []Cell) Wave {
        return Wave{
            .cells = cells,
        };
    }

    fn collapse(self: Wave, rand: std.Random) void {
        var min: usize = std.math.maxInt(usize);
        for (self.cells) |cell| {
            const tiles = cell.possible_tiles.items.len;
            if (cell.collapsed_tile == null and tiles < min) {
                min = tiles;
            }
        }

        if (min == 0) return;

        var num_min: u32 = 0;
        for (self.cells) |cell| {
            const tiles = cell.possible_tiles.items.len;
            if (tiles == min) {
                num_min += 1;
            }
        }

        if (num_min == 0) return;

        const cell_index = rand.uintLessThan(usize, num_min);
        var current_min: i32 = 0;

        var cell = blk: {
            for (self.cells) |*cell| {
                const possible = cell.possible_tiles.items.len;
                if (possible == min) {
                    if (cell_index == current_min) {
                        break :blk cell;
                    }
                    current_min += 1;
                }
            }
            unreachable;
        };

        const tile_index = rand.uintLessThan(usize, cell.possible_tiles.items.len);
        const collapsed_tile = cell.possible_tiles.items[tile_index];

        cell.collapsed_tile = collapsed_tile;
        cell.possible_tiles.clearRetainingCapacity();

        const x: usize = @intCast(cell.x);
        const y: usize = @intCast(cell.y);

        if (x > 0) {
            var leftCell = &self.cells[y * COLUMNS + x - 1];
            leftCell.reduceOptions(collapsed_tile, LEFT);
        }
        if (x < COLUMNS - 1) {
            var rightCell = &self.cells[y * COLUMNS + x + 1];
            rightCell.reduceOptions(collapsed_tile, RIGHT);
        }
        if (y > 0) {
            var upCell = &self.cells[(y - 1) * COLUMNS + x];
            upCell.reduceOptions(collapsed_tile, UP);
        }
        if (y < ROWS - 1) {
            var downCell = &self.cells[(y + 1) * COLUMNS + x];
            downCell.reduceOptions(collapsed_tile, DOWN);
        }
    }
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

    rl.setTraceLogLevel(rl.TraceLogLevel.none);
    rl.initWindow(WIDTH, HEIGHT, "Wave function collapse");
    defer rl.closeWindow();

    var tiles = ArrayList(Tile).init(alloc);
    defer {
        for (tiles.items) |*tile| tile.deinit(alloc);
        tiles.deinit();
    }

    var assets_dir = try std.fs.cwd().openDir("assets/simple", .{ .iterate = true });
    var iter = assets_dir.iterate();

    while (try iter.next()) |file| {
        const path = try std.fmt.allocPrintZ(alloc, "assets/simple/{s}", .{file.name});
        const temp = try Tile.tiles_from_img(path, alloc);
        try tiles.appendSlice(temp.items);
        temp.deinit();
    }

    for (tiles.items) |*t1| {
        try t1.addNeighbors(tiles);
    }

    var cells = [_]Cell{undefined} ** (ROWS * COLUMNS);

    for (0..ROWS) |y| {
        for (0..COLUMNS) |x| {
            var tile_ptrs = ArrayList(*Tile).init(alloc);
            for (tiles.items) |*tile| {
                try tile_ptrs.append(tile);
            }
            cells[y * COLUMNS + x] = Cell.init(@intCast(x), @intCast(y), tile_ptrs);
        }
    }

    const wave = Wave.init(&cells);
    wave.collapse(rand);

    rl.setTargetFPS(60);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        for (0..10) |_|
            wave.collapse(rand);

        for (cells) |cell| {
            cell.draw();
        }

        // print("{}\n", .{rl.getFrameTime()});
    }
}
