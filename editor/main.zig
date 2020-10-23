const std = @import("std");
const aya = @import("aya");
usingnamespace @import("imgui");
const Editor = @import("editor.zig").Editor;

pub const imgui = true;
var editor: Editor = undefined;

pub fn main() !void {
    try aya.run(.{
        .init = init,
        .update = update,
        .render = render,
        .shutdown = shutdown,
        .onFileDropped = Editor.onFileDropped,
        .gfx = .{
            .resolution_policy = .none,
        },
        .window = .{
            .width = 1280,
            .height = 800,
            .title = "Aya Edit",
        },
    });
}

fn init() void {
    editor = Editor.init();

    var io = igGetIO();
    io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;
    io.ConfigDockingWithShift = true;

    igGetStyle().FrameRounding = 0;
    igGetStyle().WindowRounding = 0;
}

fn shutdown() void {
    editor.deinit();
}

fn update() void {
    beginDock();
    editor.update();
    igEnd();
}

fn render() void {
    aya.gfx.beginNullPass();
}

fn beginDock() void {
    const vp = igGetMainViewport();
    var work_pos = ImVec2{};
    var work_size = ImVec2{};
    ImGuiViewport_GetWorkPos(&work_pos, vp);
    ImGuiViewport_GetWorkSize(&work_size, vp);

    igSetNextWindowPos(work_pos, ImGuiCond_Always, .{});
    igSetNextWindowSize(work_size, ImGuiCond_Always);
    igSetNextWindowViewport(vp.ID);

    var window_flags = ImGuiWindowFlags_NoDocking | ImGuiWindowFlags_MenuBar;
    window_flags |= ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove;
    window_flags |= ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoNavFocus;

    igPushStyleVarVec2(ImGuiStyleVar_WindowPadding, .{});
    _ = igBegin("Dockspace", null, window_flags);
    igPopStyleVar(1);

    const io = igGetIO();
    const dockspace_id = igGetIDStr("aya-dockspace");
    // igDockBuilderRemoveNode(dockspace_id); // uncomment for testing initial layout setup code
    if (igDockBuilderGetNode(dockspace_id) == null) {
        var dock_main_id = igDockBuilderAddNode(dockspace_id, ImGuiDockNodeFlags_DockSpace);
        igDockBuilderSetNodeSize(dockspace_id, work_size);
        setupDockLayout(dock_main_id);
    }

    igDockSpace(dockspace_id, .{}, ImGuiDockNodeFlags_None, null);
}

fn setupDockLayout(id: ImGuiID) void {
    var dock_main_id = id;

    // dock_main_id is the left node after this
    const right_id = igDockBuilderSplitNode(dock_main_id, ImGuiDir_Right, 0.3, null, &dock_main_id);

    // dock_main_id is the center node after this
    const left_id = igDockBuilderSplitNode(dock_main_id, ImGuiDir_Left, 0.3, null, &dock_main_id);

    // bottom_left_id is the bottom node after this
    var bottom_left_id: ImGuiID = 0;
    const top_left_id = igDockBuilderSplitNode(left_id, ImGuiDir_Up, 0.3, null, &bottom_left_id);
    igDockBuilderDockWindow("Layers", top_left_id);
    igDockBuilderDockWindow("Entities", bottom_left_id);

    // bottom_left_id is the bottom node after this
    var bottom_right_id: ImGuiID = 0;
    var top_right_id = igDockBuilderSplitNode(right_id, ImGuiDir_Up, 0.65, null, &bottom_right_id);
    igDockBuilderDockWindow("Inspector", top_right_id);
    igDockBuilderDockWindow("Rules", top_right_id);
    // igDockBuilderDockWindow("Palette", bottom_right_id);

    // dock_main_id is the bottom node after this
    const tl_id = igDockBuilderSplitNode(dock_main_id, ImGuiDir_Up, 0.75, null, &dock_main_id);
    igDockBuilderDockWindow("Scene", tl_id);
    igDockBuilderDockWindow("Assets", dock_main_id);

    igDockBuilderFinish(id);
}
