const std = @import("std");
const rl = @import("raylib");
pub const shapes = @import("shapes.zig");

const Rectangle = shapes.Rectangle;
const Circle = shapes.Circle;

pub fn QTree(comptime T: type, comptime max_children: comptime_int) type {
    if (!@hasField(T, "x") or !@hasField(T, "y")) {
        @compileError("Type " ++ @typeName(T) ++ " must have fields x and y");
    }

    return struct {
        const Self = @This();
        alloc: std.mem.Allocator,

        bounds: Rectangle,
        children: [4]*Self = undefined,
        split: bool = false,

        items: std.BoundedArray(*const T, max_children),

        pub fn init(bound: Rectangle, alloc: std.mem.Allocator) Self {
            return .{
                .alloc = alloc,
                .bounds = bound,
                .items = std.BoundedArray(*const T, max_children).init(0) catch unreachable,
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

            // If full, then split
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

                self.children[0].* = Self.init(nw_rect, self.alloc);
                self.children[1].* = Self.init(ne_rect, self.alloc);
                self.children[2].* = Self.init(sw_rect, self.alloc);
                self.children[3].* = Self.init(se_rect, self.alloc);
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

        pub fn query(self: *Self, circle: Circle, out: *std.ArrayList(*const T)) !void {
            if (!self.bounds.overlapsCircle(circle)) return;

            if (!self.split) {
                for (self.items.constSlice()) |item| {
                    if (circle.contains(item))
                        try out.append(item);
                }
                return;
            }

            for (self.children) |child| {
                try child.query(circle, out);
            }
        }

        pub fn queryXYR(self: *Self, x: i32, y: i32, r: i32, out: *std.ArrayList(*const T)) !void {
            try self.query(.{ .x = x, .y = y, .r = r }, out);
        }

        pub fn draw(self: *Self) void {
            self.bounds.draw(null);

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

        pub fn itemCount(self: *Self) usize {
            var count: usize = self.items.len;

            if (self.split) {
                for (self.children) |child| {
                    count += child.itemCount();
                }
            }

            return count;
        }

        pub fn clear(self: *Self) void {
            if (self.split) {
                for (self.children) |child| {
                    child.clear();
                    self.alloc.destroy(child);
                }
                self.split = false;
            }
            self.items.resize(0) catch unreachable;
        }
    };
}
