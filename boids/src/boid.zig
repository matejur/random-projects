const rl = @import("raylib");

const CENTERING_FACTOR = 0.005;
const MATCHING_FACTOR = 0.05;
const AVOID_FACTOR = 0.08;

const MIN_SPEED = 3;
const MAX_SPEED = 15;

const TURN = 0.3;

pub const Boid = struct {
    x: i32,
    y: i32,
    vx: f32 = 1,
    vy: f32 = 1,

    pub fn separate(self: *Boid, others: []*const Boid) void {
        var close_dx: i32 = 0;
        var close_dy: i32 = 0;

        for (others) |other| {
            if (other == self) continue;
            close_dx += self.x - other.x;
            close_dy += self.y - other.y;
        }

        self.vx += @as(f32, @floatFromInt(close_dx)) * AVOID_FACTOR;
        self.vy += @as(f32, @floatFromInt(close_dy)) * AVOID_FACTOR;
    }

    pub fn alignment(self: *Boid, others: []*const Boid) void {
        //if only this bird
        if (others.len < 2) return;

        var xvel_avg: f32 = 0;
        var yvel_avg: f32 = 0;

        for (others) |other| {
            if (other == self) continue;
            xvel_avg += other.vx;
            yvel_avg += other.vy;
        }

        xvel_avg /= @floatFromInt(others.len - 1);
        yvel_avg /= @floatFromInt(others.len - 1);

        self.vx += (xvel_avg - self.vx) * MATCHING_FACTOR;
        self.vy += (yvel_avg - self.vy) * MATCHING_FACTOR;
    }

    pub fn cohesion(self: *Boid, others: []*const Boid) void {
        //if only this bird
        if (others.len < 2) return;

        var xpos_avg: f32 = 0;
        var ypos_avg: f32 = 0;

        for (others) |other| {
            if (other == self) continue;
            xpos_avg += @as(f32, @floatFromInt(other.x));
            ypos_avg += @as(f32, @floatFromInt(other.y));
        }

        xpos_avg /= @floatFromInt(others.len - 1);
        ypos_avg /= @floatFromInt(others.len - 1);

        self.vx += (xpos_avg - @as(f32, @floatFromInt(self.x))) * CENTERING_FACTOR;
        self.vy += (ypos_avg - @as(f32, @floatFromInt(self.y))) * CENTERING_FACTOR;
    }

    pub fn constrainSpeed(self: *Boid) void {
        const speed = @sqrt(self.vx * self.vx + self.vy * self.vy);

        if (speed > MAX_SPEED) {
            self.vx = (self.vx / speed) * MAX_SPEED;
            self.vy = (self.vy / speed) * MAX_SPEED;
        } else if (speed < MIN_SPEED) {
            self.vx = (self.vx / speed) * MIN_SPEED;
            self.vy = (self.vy / speed) * MIN_SPEED;
        }
    }

    pub fn avoidEdges(self: *Boid, left: i32, top: i32, right: i32, bottom: i32) void {
        if (self.x < left) self.vx += TURN;
        if (self.x > right) self.vx -= TURN;
        if (self.y > bottom) self.vy -= TURN;
        if (self.y < top) self.vy += TURN;
    }

    pub fn update(self: *Boid) void {
        self.x = @intFromFloat(@as(f32, @floatFromInt(self.x)) + self.vx);
        self.y = @intFromFloat(@as(f32, @floatFromInt(self.y)) + self.vy);
    }

    pub fn draw(self: Boid) void {
        rl.drawCircle(self.x, self.y, 5, rl.Color.white);
    }
};
