const std = @import("std");
const rl = @import("raylib");

const CELL_SIZE = 64;
const HEIGHT = CELL_SIZE * 10;
const WIDTH = CELL_SIZE * 10;

const Tile = struct {
    texture: rl.Texture,
    edges: [4][CELL_SIZE]usize,

    pub fn init(path: [*:0]const u8) !Tile {
        var img = try rl.loadImage(path);
        img.resizeNN(CELL_SIZE, CELL_SIZE);

        const pixels = try rl.loadImageColors(img);

        var edges: [4][CELL_SIZE]usize = undefined;

        var y: u16 = 0;
        while (y < CELL_SIZE) : (y += 1) {
            var x: u16 = 0;
            while (x < CELL_SIZE) : (x += 1) {
                const pixel = pixels[x + CELL_SIZE * y];
                const value: usize = @as(usize, pixel.r) * 255 * 255 + @as(usize, pixel.g) * 255 + @as(usize, pixel.b);
                if (y == 0) {
                    edges[0][x] = value;
                }
                if (x == CELL_SIZE - 1) {
                    edges[1][y] = value;
                }
                if (y == CELL_SIZE - 1) {
                    edges[2][x] = value;
                }
                if (x == 0) {
                    edges[3][y] = value;
                }
            }
        }

        return Tile{ .edges = edges, .texture = try img.toTexture() };
    }
};

pub fn main() !void {
    rl.initWindow(WIDTH, HEIGHT, "Test");
    defer rl.closeWindow();

    const cross = try Tile.init("assets/cross.png");
    const line = try Tile.init("assets/line.png");

    rl.setTargetFPS(30);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.drawTexture(cross.texture, 0, 0, rl.Color.white);
        rl.drawTexture(line.texture, 0, CELL_SIZE, rl.Color.white);
    }
}
