const std = @import("std");
const rl = @import("raylib");
const print = std.debug.print;

const PLAYER_SPEED = 2;

const WIDTH = 1024;
const HEIGHT = 512;

const GRID_SIZE = 16;
const CELL_SIZE = HEIGHT / GRID_SIZE;

const PI = 3.14159274101257324;
const RAY_NUM = WIDTH / 2;

var grid: [GRID_SIZE * GRID_SIZE]?rl.Color = .{null} ** (GRID_SIZE * GRID_SIZE);

fn drawGrid() void {
    for (1..GRID_SIZE) |ut| {
        const t: i32 = @intCast(ut);
        rl.drawLine(0, t * CELL_SIZE, WIDTH / 2, t * CELL_SIZE, rl.Color.black);
        rl.drawLine(t * CELL_SIZE, 0, t * CELL_SIZE, HEIGHT, rl.Color.black);
    }
    rl.drawLine(GRID_SIZE * CELL_SIZE, 0, GRID_SIZE * CELL_SIZE, HEIGHT, rl.Color.black);
}

fn drawMinimap() void {
    for (0..GRID_SIZE) |x| {
        for (0..GRID_SIZE) |y| {
            rl.drawRectangle(
                @intCast(x * CELL_SIZE),
                @intCast(y * CELL_SIZE),
                CELL_SIZE,
                CELL_SIZE,
                grid[y * GRID_SIZE + x] orelse rl.Color.white,
            );
        }
    }
    drawGrid();
}

const HitInfo = struct {
    dist: f32,
    color: rl.Color,
};

const Player = struct {
    pos: rl.Vector2,
    dir: rl.Vector2 = rl.Vector2.init(1, 0),
    plane: rl.Vector2 = rl.Vector2.init(0, 0.66),

    fn draw(self: *Player) void {
        rl.drawCircleV(self.pos.scale(CELL_SIZE), 5, rl.Color.orange);
        rl.drawLineEx(self.pos.scale(CELL_SIZE), self.pos.scale(CELL_SIZE).add(self.dir.scale(10)), 5, rl.Color.red);

        for (0..RAY_NUM) |i| {
            const cameraX = 2 * @as(f32, @floatFromInt(i)) / RAY_NUM - 1;
            const dir = self.dir.add(self.plane.scale(cameraX));

            const hitInfo = raycast(self.pos, dir);

            if (hitInfo) |info| {
                const dist: i32 = @intFromFloat(HEIGHT / info.dist);
                rl.drawRectangle(WIDTH / 2 + @as(i32, @intCast(i)), HEIGHT / 2 - @divFloor(dist, 2), 1, dist, info.color);
            }
        }
    }

    fn move(self: *Player) void {
        var displacement = rl.Vector2.zero();
        if (rl.isKeyDown(rl.KeyboardKey.w)) displacement = displacement.add(self.dir);
        if (rl.isKeyDown(rl.KeyboardKey.s)) displacement = displacement.subtract(self.dir);

        if (rl.isKeyDown(rl.KeyboardKey.d)) {
            self.dir = self.dir.rotate(0.1);
            self.plane = self.plane.rotate(0.1);
        }

        if (rl.isKeyDown(rl.KeyboardKey.a)) {
            self.dir = self.dir.rotate(-0.1);
            self.plane = self.plane.rotate(-0.1);
        }

        self.pos = self.pos.add(displacement.scale(PLAYER_SPEED * rl.getFrameTime()));
    }
};

fn raycast(start: rl.Vector2, dir: rl.Vector2) ?HitInfo {
    const stepSize = rl.Vector2.init(
        @abs(1 / dir.x),
        @abs(1 / dir.y),
    );

    var mapPos = rl.Vector2.init(
        @floor(start.x),
        @floor(start.y),
    );

    const step = rl.Vector2.init(
        if (dir.x < 0) -1 else 1,
        if (dir.y < 0) -1 else 1,
    );

    var rayLength = rl.Vector2.zero();

    if (dir.x < 0) {
        rayLength.x = (start.x - mapPos.x) * stepSize.x;
    } else {
        rayLength.x = (mapPos.x + 1 - start.x) * stepSize.x;
    }

    if (dir.y < 0) {
        rayLength.y = (start.y - mapPos.y) * stepSize.y;
    } else {
        rayLength.y = (mapPos.y + 1 - start.y) * stepSize.y;
    }

    var distance: f32 = 0.0;
    var side = false;

    while (true) {
        if (rayLength.x < rayLength.y) {
            mapPos.x += step.x;
            distance = rayLength.x;
            rayLength.x += stepSize.x;
            side = true;
        } else {
            mapPos.y += step.y;
            distance = rayLength.y;
            rayLength.y += stepSize.y;
            side = false;
        }

        if (mapPos.x >= 0 and mapPos.x < GRID_SIZE and mapPos.y >= 0 and mapPos.y < GRID_SIZE) {
            const idx = @as(usize, @intFromFloat(mapPos.x)) + @as(usize, @intFromFloat(mapPos.y)) * GRID_SIZE;
            const tile = grid[idx];

            if (tile) |t| {
                const dist = if (side) rayLength.x - stepSize.x else rayLength.y - stepSize.y;
                return HitInfo{
                    .dist = dist,
                    .color = t,
                };
            }
        } else {
            return null;
        }
    }
}

pub fn main() !void {
    rl.initWindow(WIDTH, HEIGHT, "Raycasting");
    rl.setWindowPosition(3200, 150);
    defer rl.closeWindow();

    var player = Player{ .pos = .{
        .x = GRID_SIZE / 2 + 0.5,
        .y = GRID_SIZE / 2 + 0.5,
    } };

    var currentColor = rl.Color.red;

    rl.setTargetFPS(30);
    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        const mouse = rl.getMousePosition();

        if (rl.isMouseButtonPressed(rl.MouseButton.left)) {
            const x: usize = @intFromFloat(mouse.x / CELL_SIZE);
            const y: usize = @intFromFloat(mouse.y / CELL_SIZE);

            if (x < GRID_SIZE and y < GRID_SIZE) {
                const idx: usize = y * GRID_SIZE + x;
                if (grid[idx] != null) {
                    grid[idx] = null;
                } else {
                    grid[idx] = currentColor;
                }
            }
        }

        if (rl.isKeyPressed(rl.KeyboardKey.r)) currentColor = rl.Color.red;
        if (rl.isKeyPressed(rl.KeyboardKey.g)) currentColor = rl.Color.green;
        if (rl.isKeyPressed(rl.KeyboardKey.b)) currentColor = rl.Color.blue;

        drawMinimap();

        player.move();
        player.draw();
    }
}
