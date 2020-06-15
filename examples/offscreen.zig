const std = @import("std");
const aya = @import("aya");
const math = aya.math;

var checker_tex: aya.gfx.Texture = undefined;
var font_tex: aya.gfx.Texture = undefined;
var rt: aya.gfx.RenderTexture = undefined;

pub fn main() !void {
    try aya.run(.{
        .init = init,
        .update = update,
        .render = render,
    });

    checker_tex.deinit();
    font_tex.deinit();
    rt.deinit();
}

fn init() void {
    var shader = aya.gfx.Shader.initFromFile("assets/SpriteEffect.fxb") catch unreachable;
    var mat = aya.math.Mat32.initOrtho(640, 480);
    shader.setParam(aya.math.Mat32, "TransformMatrix", mat);
    shader.apply();

    checker_tex = aya.gfx.Texture.initCheckerboard();
    font_tex = aya.gfx.Texture.initFromFile("assets/font.png") catch unreachable;
    rt = aya.gfx.RenderTexture.init(52, 52);
}

fn update() void {}

fn render() void {
    aya.gfx.beginPass();
    aya.draw.texScale(checker_tex, 5, 5, 10);
    aya.draw.texScale(checker_tex, 55, 55, 2);

    aya.draw.texScale(font_tex, 200, 100, 0.2);
    aya.draw.texScale(font_tex, 300, 200, 0.2);

    aya.draw.line(aya.math.Vec2.init(0, 0), aya.math.Vec2.init(640, 480), 2, aya.math.Color.blue);
    aya.draw.point(math.Vec2.init(350, 350), 10, math.Color.sky_blue);
    aya.draw.point(math.Vec2.init(380, 380), 15, math.Color.magenta);
    aya.draw.rect(math.Vec2.init(387, 372), 40, 15, math.Color.dark_brown);
    aya.draw.hollowRect(math.Vec2.init(430, 372), 40, 15, 2, math.Color.yellow);
    aya.draw.circle(math.Vec2.init(100, 350), 20, 1, 12, math.Color.orange);

    const poly = [_]math.Vec2{ .{ .x = 400, .y = 30 }, .{ .x = 420, .y = 10 }, .{ .x = 430, .y = 80 }, .{ .x = 410, .y = 60 }, .{ .x = 375, .y = 40 } };
    aya.draw.hollowPolygon(poly[0..], 2, math.Color.gold);
    aya.gfx.endPass();

    aya.gfx.beginPass();
    aya.gfx.setRenderTexture(rt);
    aya.gfx.clear(aya.math.Color.lime);
    var i = @as(usize, 0);
    while (i <= @divFloor(rt.tex.width, checker_tex.width)) : (i += 1) {
        aya.draw.tex(checker_tex, @intToFloat(f32, i * 4), @intToFloat(f32, i * 2 + 10));
    }
    aya.gfx.endPass();

    aya.gfx.beginPass();
    aya.debug.drawPoint(math.Vec2.init(40, 400), 60, null);
    aya.gfx.setRenderTexture(null);
    aya.draw.texScale(rt.tex, 70, 200, 2);
    aya.gfx.endPass();
}
