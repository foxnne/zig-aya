const std = @import("std");
const aya = @import("../../aya.zig");
const stb_image = @import("stb");
const renderkit = @import("renderkit");
const renderer = renderkit.renderer;
const fs = aya.fs;

pub const Texture = struct {
    img: renderkit.Image,
    width: f32 = 0,
    height: f32 = 0,

    pub fn init(width: i32, height: i32) Texture {
        return initWithOptions(width, height, .nearest, .clamp);
    }

    pub fn initWithOptions(width: i32, height: i32, filter: renderkit.TextureFilter, wrap: renderkit.TextureWrap) Texture {
        return initWithDataOptions(u8, width, height, &[_]u8{}, filter, wrap);
    }

    pub fn initFromFile(file: []const u8, filter: renderkit.TextureFilter) !Texture {
        const image_contents = try fs.read(aya.mem.tmp_allocator, file);

        var w: c_int = undefined;
        var h: c_int = undefined;
        var channels: c_int = undefined;
        const load_res = stb_image.stbi_load_from_memory(image_contents.ptr, @intCast(c_int, image_contents.len), &w, &h, &channels, 4);
        if (load_res == null) return error.ImageLoadFailed;
        defer stb_image.stbi_image_free(load_res);

        return initWithDataOptions(u8, w, h, load_res[0..@intCast(usize, w * h * channels)], filter, .clamp);
    }

    pub fn initWithData(comptime T: type, width: i32, height: i32, pixels: []T) Texture {
        return initWithDataOptions(T, width, height, pixels, .nearest, .clamp);
    }

    pub fn initWithDataOptions(comptime T: type, width: i32, height: i32, pixels: []T, filter: renderkit.TextureFilter, wrap: renderkit.TextureWrap) Texture {
        const img = renderer.createImage(.{
            .width = width,
            .height = height,
            .min_filter = filter,
            .mag_filter = filter,
            .wrap_u = wrap,
            .wrap_v = wrap,
            .content = std.mem.sliceAsBytes(pixels),
        });
        return .{
            .img = img,
            .width = @intToFloat(f32, width),
            .height = @intToFloat(f32, height),
        };
    }

    pub fn initCheckerTexture() Texture {
        var pixels = [_]u32{
            0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
            0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
            0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
            0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
        };

        return initWithData(u32, 4, 4, &pixels);
    }

    pub fn initSingleColor(color: u32) Texture {
        var pixels: [16]u32 = undefined;
        std.mem.set(u32, &pixels, color);
        return initWithData(u32, 4, 4, pixels[0..]);
    }

    pub fn initOffscreen(width: i32, height: i32, filter: renderkit.TextureFilter, wrap: renderkit.TextureWrap) Texture {
        const img = renderer.createImage(.{
            .render_target = true,
            .width = width,
            .height = height,
            .min_filter = filter,
            .mag_filter = filter,
            .wrap_u = wrap,
            .wrap_v = wrap,
        });
        return .{
            .img = img,
            .width = @intToFloat(f32, width),
            .height = @intToFloat(f32, height),
        };
    }

    pub fn initStencil(width: i32, height: i32, filter: renderkit.TextureFilter, wrap: renderkit.TextureWrap) Texture {
        const img = renderer.createImage(.{
            .render_target = true,
            .pixel_format = .stencil,
            .width = width,
            .height = height,
            .min_filter = filter,
            .mag_filter = filter,
            .wrap_u = wrap,
            .wrap_v = wrap,
        });
        return .{
            .img = img,
            .width = @intToFloat(f32, width),
            .height = @intToFloat(f32, height),
        };
    }

    pub fn deinit(self: *const Texture) void {
        renderer.destroyImage(self.img);
    }

    pub fn setData(self: *Texture, comptime T: type, data: []T) void {
        renderer.updateImage(T, self.img, data);
    }

    pub fn resize(self: *Texture, width: i32, height: i32) void {
        self.deinit();
        self.* = Texture.init(width, height);
        std.debug.print("----- TODO: recreate render textures correctly with depth/stencil\n", .{});
    }
};
