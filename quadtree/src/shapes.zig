const std = @import("std");
const rl = @import("raylib");

pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn init(x: i32, y: i32, width: i32, height: i32) Rectangle {
        return Rectangle{
            .x = x,
            .y = y,
            .width = width,
            .height = height,
        };
    }

    pub fn contains(self: Rectangle, point: anytype) bool {
        return point.x >= self.x and point.x <= self.x + self.width and
            point.y >= self.y and point.y <= self.y + self.height;
    }

    pub fn overlapsCircle(self: Rectangle, circle: Circle) bool {
        const x1 = self.x;
        const x2 = self.x + self.width;
        const y1 = self.y;
        const y2 = self.y + self.height;

        if (x1 < circle.x and x2 < circle.x and y1 < circle.y and y2 < circle.y) return true;

        const nearestX = @max(x1, @min(circle.x, x2));
        const nearestY = @max(y1, @min(circle.y, y2));

        const dx = circle.x - nearestX;
        const dy = circle.y - nearestY;
        const distSq = dx * dx + dy * dy;

        return distSq < circle.r * circle.r;
    }

    pub fn draw(self: Rectangle, color: ?rl.Color) void {
        rl.drawRectangleLines(
            self.x,
            self.y,
            self.width,
            self.height,
            color orelse rl.Color.white,
        );
    }
};

pub const Circle = struct {
    x: i32,
    y: i32,
    r: i32,

    pub fn init(x: i32, y: i32, r: i32) Circle {
        return .{
            .x = x,
            .y = y,
            .r = r,
        };
    }

    pub fn draw(self: Circle) void {
        rl.drawCircleLines(self.x, self.y, @floatFromInt(self.r), rl.Color.green);
    }

    pub fn contains(self: Circle, point: anytype) bool {
        const dx = self.x - point.x;
        const dy = self.y - point.y;
        const rr = self.r * self.r;

        return (dx * dx + dy * dy) < rr;
    }
};
