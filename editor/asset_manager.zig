const std = @import("std");
const fs = std.fs;
const aya = @import("aya");
usingnamespace @import("imgui");
const root = @import("main.zig");
const Atlas = @import("utils/texture_packer.zig").Atlas;

/// takes ownership of the Atlas passed in!
const ThumbnailAtlas = struct {
    tex: aya.gfx.Texture = undefined,
    names: [][:0]const u8,
    uvs: []Uv,

    const Uv = struct {
        tl: ImVec2,
        br: ImVec2,
    };

    pub fn initEmpty() ThumbnailAtlas {
        return .{
            .names = &[_][:0]const u8{},
            .uvs = &[_]Uv{},
        };
    }

    pub fn init(atlas: Atlas) ThumbnailAtlas {
        var uvs = aya.mem.allocator.alloc(Uv, atlas.rects.len) catch unreachable;
        for (uvs) |*uv, i| {
            const rect = atlas.rects[i];
            uv.tl.x = @intToFloat(f32, rect.x) / @intToFloat(f32, atlas.image.w);
            uv.tl.y = @intToFloat(f32, rect.y) / @intToFloat(f32, atlas.image.h);
            uv.br.x = uv.tl.x + @intToFloat(f32, rect.w) / @intToFloat(f32, atlas.image.w);
            uv.br.y = uv.tl.y + @intToFloat(f32, rect.h) / @intToFloat(f32, atlas.image.h);
        }

        defer aya.mem.allocator.free(atlas.rects);
        defer atlas.image.deinit();
        return .{
            .tex = aya.gfx.Texture.initWithData(u32, atlas.w, atlas.h, atlas.image.pixels),
            .names = atlas.names,
            .uvs = uvs,
        };
    }

    pub fn deinit(self: @This()) void {
        // we could have an undefind Texture so avoid deiniting it
        if (self.names.len > 0) self.tex.deinit();
        for (self.names) |name|
            aya.mem.allocator.free(name);
        aya.mem.allocator.free(self.names);
        aya.mem.allocator.free(self.uvs);
    }
};

/// takes ownership of the Atlas passed in!
pub const TextureAtlas = struct {
    tex: aya.gfx.Texture = undefined,
    names: [][:0]const u8,
    rects: []aya.math.RectI,
    
    pub fn initEmpty() TextureAtlas {
        return .{
            .names = &[_][:0]const u8{},
            .rects = &[_]aya.math.RectI{},
        };
    }

    pub fn init(atlas: Atlas) TextureAtlas {
        defer atlas.image.deinit();
        return .{
            .tex = aya.gfx.Texture.initWithData(u32, atlas.w, atlas.h, atlas.image.pixels),
            .names = atlas.names,
            .rects = atlas.rects,
        };
    }

    pub fn deinit(self: @This()) void {
        if (self.names.len > 0) self.tex.deinit();
        for (self.names) |name|
            aya.mem.allocator.free(name);
        aya.mem.allocator.free(self.names);
        aya.mem.allocator.free(self.rects);
    }

    pub fn indexOfTexture(self: @This(), tex_name: [:0]const u8) usize {
        for (self.names) |name, i| {
            if (std.mem.eql(u8, name, tex_name)) return i;
        }
        unreachable;
    }
};

pub const AssetManager = struct {
    root_path: [:0]const u8 = "",
    default_tex: aya.gfx.Texture,
    thumbnails: ThumbnailAtlas = ThumbnailAtlas.initEmpty(),
    textures: TextureAtlas = TextureAtlas.initEmpty(),
    tilesets: [][:0]const u8 = &[_][:0]u8{},

    pub fn init() AssetManager {
        return .{ .default_tex = aya.gfx.Texture.initCheckerTexture(8) };
    }

    pub fn deinit(self: @This()) void {
        if (self.root_path.len > 0) aya.mem.allocator.free(self.root_path);
        self.default_tex.deinit();
        self.thumbnails.deinit();
        self.textures.deinit();
        aya.mem.allocator.free(self.tilesets);
    }

    pub fn getUvsForThumbnailAtIndex(self: @This(), index: usize) ThumbnailAtlas.Uv {
        return self.thumbnails.uvs[index];
    }

    pub fn getUvsForThumbnail(self: @This(), name: [:0]const u8) ThumbnailAtlas.Uv {
        // special case for the default texture, which is called "def"
        if (std.mem.eql(u8, name, "def"))
            return ThumbnailAtlas.Uv{
                .tl = .{},
                .br = .{ .x = 1, .y = 1 },
            };
        return self.thumbnails.uvs[self.indexOfTexture(self.thumbnails.names, name).?];
    }

    /// returns the Texture that contains the image. Currently we only keep one atlas so its pretty useless but if we support multiple atlases later ;)
    pub fn getTextureAndRect(self: @This(), name: [:0]const u8) struct { tex: aya.gfx.Texture, rect: aya.math.RectI } {
        return .{ .tex = self.textures.tex, .rect = self.textures.rects[self.indexOfTexture(self.textures.names, name).?] };
    }

    /// gets the Texture and UVs appropropriate for adding a Dear ImGui image to the draw list
    pub fn getTextureAndUvs(self: @This(), name: [:0]const u8) struct { tex: aya.gfx.Texture, uvs: ThumbnailAtlas.Uv, rect: aya.math.RectI } {
        const rect = self.textures.rects[self.indexOfTexture(self.textures.names, name).?];
        var uv = ThumbnailAtlas.Uv{ .tl = .{}, .br = .{} };
        uv.tl.x = @intToFloat(f32, rect.x) / self.textures.tex.width;
        uv.tl.y = @intToFloat(f32, rect.y) / self.textures.tex.height;
        uv.br.x = uv.tl.x + @intToFloat(f32, rect.w) / self.textures.tex.width;
        uv.br.y = uv.tl.y + @intToFloat(f32, rect.h) / self.textures.tex.height;

        return .{ .tex = self.textures.tex, .uvs = uv, .rect = rect };
    }

    fn indexOfTexture(self: @This(), haystack: [][:0]const u8, name: [:0]const u8) ?usize {
        return for (haystack) |slice, i| {
            if (std.mem.eql(u8, slice, name)) break @as(?usize, i);
        } else @as(?usize, null);
    }

    /// sets the root project path and starts a scan of the subfolders to load up the asset state
    pub fn setRootPath(self: *@This(), path: []const u8) void {
        if (self.root_path.len > 0) aya.mem.allocator.free(self.root_path);
        self.root_path = aya.mem.allocator.dupeZ(u8, path) catch unreachable;
        var dir = std.fs.cwd().openDir(self.root_path, .{}) catch unreachable;
        dir.setAsCwd() catch unreachable;
        dir.close();

        const tex_folder = fs.path.join(aya.mem.allocator, &[_][]const u8{ self.root_path, "textures" }) catch unreachable;
        defer aya.mem.allocator.free(tex_folder);

        self.generateThumbnailAtlas(tex_folder);
        self.generateTextureAtlas(tex_folder);
        self.loadTilesets();
    }

    fn generateThumbnailAtlas(self: *@This(), tex_folder: []const u8) void {
        const thumb_atlas = root.utils.texture_packer.packThumbnails(tex_folder, 90) catch unreachable;
        self.thumbnails.deinit();
        self.thumbnails = ThumbnailAtlas.init(thumb_atlas);
    }

    fn generateTextureAtlas(self: *@This(), tex_folder: []const u8) void {
        const atlas = root.utils.texture_packer.pack(tex_folder) catch unreachable;
        self.textures.deinit();
        self.textures = TextureAtlas.init(atlas);
    }

    fn loadTilesets(self: *@This()) void {
        const src_folder = fs.path.join(aya.mem.tmp_allocator, &[_][]const u8{ self.root_path, "tilesets" }) catch unreachable;
        const pngs = aya.fs.getAllFilesOfType(aya.mem.allocator, src_folder, ".png", true);
        defer aya.mem.allocator.free(pngs);

        aya.mem.allocator.free(self.tilesets);
        self.tilesets = aya.mem.allocator.alloc([:0]u8, pngs.len) catch unreachable;
        for (pngs) |png, i| self.tilesets[i] = aya.mem.allocator.dupeZ(u8, std.fs.path.basename(png)) catch unreachable;
    }
};
