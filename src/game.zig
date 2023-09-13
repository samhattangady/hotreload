const std = @import("std");
const c = @cImport({
    @cInclude("SDL.h");
});

pub const Game = struct {
    const Self = @This();
    quit: bool = false,
    should_reload_libs: bool = false,
    allocator: std.mem.Allocator,
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    box_x: f32 = 100,
    box_y: f32 = 100,
    box_w: f32 = 100,
    box_h: f32 = 80,
    speed_x: f32 = 0.03,
    speed_y: f32 = 0.03,

    pub fn init() Self {
        var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = false }){};
        if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
            c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
            unreachable;
        }
        // not doing error checks
        var window = c.SDL_CreateWindow("reload", c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 1280, 720, 0).?;
        var renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED).?;
        return .{
            .window = window,
            .renderer = renderer,
            .allocator = gpa.allocator(),
        };
    }

    pub fn deinit(self: *Self) void {
        c.SDL_Quit();
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyWindow(self.window);
        // TODO (13 Sep 2023 sam): deinit allocator?
    }

    pub fn update(self: *Self) void {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_QUIT => self.quit = true,
                c.SDL_KEYDOWN => {
                    if (event.key.keysym.sym == c.SDLK_r) self.should_reload_libs = true;
                    if (event.key.keysym.sym == c.SDLK_END) self.quit = true;
                },
                else => {},
            }
        }
        if (self.should_reload_libs) self.resetState();
        self.box_x += self.speed_x;
        if (self.box_x + self.box_w > 1280 or self.box_x < 0) self.speed_x *= -1;
        self.box_y += self.speed_y;
        if (self.box_y + self.box_h > 720 or self.box_y < 0) self.speed_y *= -1;
        self.render();
    }

    fn resetState(self: *Self) void {
        self.box_x = 100;
        self.box_y = 100;
        self.box_w = 100;
        self.box_h = 80;
        self.speed_x = 0.03;
        self.speed_y = 0.03;
    }

    pub fn render(self: *Self) void {
        _ = c.SDL_SetRenderDrawColor(self.renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(self.renderer);
        const rect: c.SDL_Rect = .{
            .x = @intFromFloat(self.box_x),
            .y = @intFromFloat(self.box_y),
            .w = @intFromFloat(self.box_w),
            .h = @intFromFloat(self.box_h),
        };
        _ = c.SDL_SetRenderDrawColor(self.renderer, 120, 220, 200, 255);
        _ = c.SDL_RenderFillRect(self.renderer, &rect);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    fn another(self: *Self) void {
        std.debug.print("{d}:\t", .{self.counter});
    }
};

pub export fn update_game(game: *Game) void {
    game.update();
}
