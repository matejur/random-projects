const std = @import("std");
const rl = @import("raylib");

const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn init(x: i32, y: i32, width: i32, height: i32) Rectangle {
        std.debug.print("Created rectangle {} {} {} {}\n", .{ x, y, width, height });
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

    pub fn draw(self: Rectangle) void {
        rl.drawRectangleLines(
            self.x,
            self.y,
            self.width,
            self.height,
            rl.Color.white,
        );
    }
};

pub fn QTree(comptime T: type) type {
    if (!@hasField(T, "x") or !@hasField(T, "y")) {
        @compileError("Type " ++ @typeName(T) ++ " must have fields x and y");
    }

    return struct {
        const Self = @This();
        alloc: std.mem.Allocator,

        bounds: Rectangle,
        children: [4]*Self = undefined,
        split: bool = false,

        items: std.BoundedArray(*const T, 4),

        pub fn init(x: i32, y: i32, width: i32, height: i32, alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .bounds = .{
                    .x = x,
                    .y = y,
                    .width = width,
                    .height = height,
                },
                .items = std.BoundedArray(*const T, 4).init(0) catch unreachable,
            };
        }

        pub fn add(self: *Self, item: *const T) !void {
            if (!self.bounds.contains(item)) return;

            if (self.split) {
                for (self.children) |child| {
                    try child.add(item);
                }
                return;
            }

            // If full, then
            self.items.append(item) catch {
                const rect = self.bounds;
                const new_width = @divFloor(rect.width, 2);
                const new_height = @divFloor(rect.height, 2);

                const nw_rect = Rectangle.init(rect.x, rect.y, new_width, new_height);
                const ne_rect = Rectangle.init(rect.x + new_width + 1, rect.y, new_width, new_height);
                const sw_rect = Rectangle.init(rect.x, rect.y + new_height + 1, new_width, new_height);
                const se_rect = Rectangle.init(rect.x + new_width + 1, rect.y + new_height + 1, new_width, new_height);

                for (&self.children) |*child| {
                    child.* = try self.alloc.create(Self);
                }

                self.children[0].* = Self.from_rectangle(nw_rect, self.alloc);
                self.children[1].* = Self.from_rectangle(ne_rect, self.alloc);
                self.children[2].* = Self.from_rectangle(sw_rect, self.alloc);
                self.children[3].* = Self.from_rectangle(se_rect, self.alloc);
                self.split = true;

                for (self.children) |child| {
                    try child.add(item);
                }

                for (self.items.constSlice()) |old| {
                    try self.add(old);
                }
                self.items.resize(0) catch unreachable;
            };
        }

        pub fn draw(self: *Self) void {
            self.bounds.draw();

            if (self.split) {
                for (self.children) |child| {
                    child.draw();
                }
            } else {
                for (self.items.constSlice()) |item| {
                    rl.drawCircle(item.x, item.y, 5, rl.Color.green);
                }
            }
        }

        fn from_rectangle(rect: Rectangle, alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .bounds = rect,
                .items = std.BoundedArray(*const T, 4).init(0) catch unreachable,
            };
        }
    };
}
