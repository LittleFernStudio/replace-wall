--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')
local material_dialog = require('gui.materials')

local config = reqscript('internal/replace-wall/config')
local manager = reqscript('internal/replace-wall/manager')
local selection = reqscript('internal/replace-wall/selection')
local state = reqscript('internal/replace-wall/state')
local tiles = reqscript('internal/replace-wall/tiles')

local texture_handles =
    dfhack.textures.loadTileset(dfhack.getHackPath() .. '/data/art/replace_wall.png', 32, 32, true)

local PREVIEW_TEXTURES = {
    paint = texture_handles[1],
    erase = texture_handles[2],
}
local PREVIEW_PENS = {
    paint = dfhack.pen.parse({
        ch = 'X',
        fg = COLOR_LIGHTCYAN,
        keep_lower = true,
    }),
    erase = dfhack.pen.parse({
        ch = 'X',
        fg = COLOR_LIGHTRED,
        keep_lower = true,
    }),
}

ReplaceWallScreen = defclass(ReplaceWallScreen, gui.ZScreen)
ReplaceWallScreen.ATTRS({
    focus_path = 'replace-wall/paint',
    pass_movement_keys = true,
    pass_mouse_clicks = true,
})

function ReplaceWallScreen:init()
    local data = state.load()

    self.material_token = data.settings.material_token
    self.item_form = data.settings.item_form

    self:cancel_drag()
    self:addviews({
        widgets.Window({
            view_id = 'window',
            frame = { l = 0, t = 8, w = 45, h = 12, xalign = 0, yalign = 0 },
            frame_title = 'Replace Wall',
            subviews = {
                widgets.HotkeyLabel({
                    frame = { l = 1, t = 1 },
                    key = 'CUSTOM_M',
                    label = function()
                        return 'Material: ' .. state.material_label(self.material_token)
                    end,
                    on_activate = self:callback('show_material_selector'),
                }),
                widgets.HotkeyLabel({
                    frame = { l = 1, t = 2 },
                    key = 'CUSTOM_B',
                    label = function()
                        local _, form = state.get_item_form(self.item_form)
                        return 'Item form: ' .. form.label
                    end,
                    on_activate = self:callback('toggle_item_form'),
                }),
                widgets.Label({
                    frame = { l = 1, t = 3 },
                    text = {
                        'LClick+drag: add straight line\n',
                        'Ctrl+LClick+drag: erase straight line\n',
                        'Shift+LClick+drag: add rectangular area\n',
                        'Ctrl+Shift+drag: erase rectangular area\n',
                        'Esc / Right-click: close',
                    },
                }),
            },
        }),
    })
end

function ReplaceWallScreen:save_settings()
    local data = state.load()

    data.settings.material_token = self.material_token
    data.settings.item_form = self.item_form

    state.save(data)
end

function ReplaceWallScreen:set_material(mat_type, mat_index)
    local mat = dfhack.matinfo.decode(mat_type, mat_index)
    if mat and state.material_is_valid(mat.material, self.item_form) then
        self.material_token = mat:getToken()
        self:save_settings()
    end
end

function ReplaceWallScreen:toggle_item_form()
    self:cancel_drag()

    self.item_form = self.item_form == 'BLOCKS' and 'BOULDER' or 'BLOCKS'

    local mat = state.resolve_material(self.material_token)
    if not mat or not state.material_is_valid(mat.material, self.item_form) then
        self.material_token = config.DEFAULT_MATERIAL_TOKEN
    end

    self:save_settings()
end

function ReplaceWallScreen:show_material_selector()
    self:cancel_drag()

    local dialog = material_dialog.MaterialDialog({
        frame_title = 'Replace Wall Material',
        prompt = 'Search materials; Esc or right-click to view all categories',
        hide_none = true,
        use_creature = false,
        mat_filter = function(mat)
            return state.material_is_valid(mat, self.item_form)
        end,
        on_select = self:callback('set_material'),
    })

    dialog:initInorganicMode()
    dialog:show()
end

function ReplaceWallScreen:cancel_drag()
    self.dragging = false
    self.drag_start = nil
    self.drag_end = nil
    self.drag_mode = nil
    self.drag_shape = nil
end

function ReplaceWallScreen:finish_drag()
    if not self.dragging then
        return
    end

    local mouse_pos = dfhack.gui.getMousePos()
    if mouse_pos then
        self.drag_end = tiles.pos(mouse_pos.x, mouse_pos.y, mouse_pos.z)
    end

    local start_pos, end_pos = self.drag_start, self.drag_end
    local mode, shape = self.drag_mode, self.drag_shape

    self:cancel_drag()

    if not start_pos or not end_pos or start_pos.z ~= end_pos.z then
        return
    end

    local positions = shape == 'area' and selection.area(start_pos, end_pos)
        or selection.line(start_pos, end_pos)
    manager.apply_selection(positions, mode)
end

function ReplaceWallScreen:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self:cancel_drag()
        self:dismiss()
        return true
    end

    if keys._MOUSE_L and self.subviews.window:getMouseFramePos() then
        return ReplaceWallScreen.super.onInput(self, keys)
    end

    local mouse_pos = dfhack.gui.getMousePos()
    if keys._MOUSE_L and mouse_pos then
        local modifiers = dfhack.internal.getModifiers()

        self.drag_mode = modifiers.ctrl and 'erase' or 'paint'
        self.drag_shape = modifiers.shift and 'area' or 'line'
        self.drag_start = tiles.pos(mouse_pos.x, mouse_pos.y, mouse_pos.z)
        self.drag_end = tiles.pos(mouse_pos.x, mouse_pos.y, mouse_pos.z)
        self.dragging = true

        return true
    end

    if self.dragging and keys._MOUSE_L_DOWN then
        if mouse_pos then
            self.drag_end = tiles.pos(mouse_pos.x, mouse_pos.y, mouse_pos.z)
        end

        return true
    end

    return ReplaceWallScreen.super.onInput(self, keys)
end

function ReplaceWallScreen:onIdle()
    if self.dragging then
        local mouse_pos = dfhack.gui.getMousePos()
        if mouse_pos then
            self.drag_end = tiles.pos(mouse_pos.x, mouse_pos.y, mouse_pos.z)
        end

        -- Release events are not reliably delivered to overlays, so read DF's button state.
        if df.global.enabler.mouse_lbut_down == 0 then
            self:finish_drag()
        end
    end

    ReplaceWallScreen.super.onIdle(self)
end

function ReplaceWallScreen:onRenderFrame(dc, rect)
    ReplaceWallScreen.super.onRenderFrame(self, dc, rect)
    if not self.dragging or not self.drag_start or not self.drag_end then
        return
    end

    if self.drag_start.z ~= df.global.window_z then
        return
    end

    local texture_handle = PREVIEW_TEXTURES[self.drag_mode]
    local preview_pen = PREVIEW_PENS[self.drag_mode]

    local viewport = guidm.Viewport.get()
    local texpos = dfhack.textures.getTexposByHandle(texture_handle)

    if not viewport or not texpos then
        return
    end

    for _, value in ipairs(selection.preview(self.drag_start, self.drag_end, self.drag_shape)) do
        local screen_pos = viewport:tileToScreen(value)
        if screen_pos then
            dfhack.screen.paintTile(preview_pen, screen_pos.x, screen_pos.y, 'X', texpos, true)
        end
    end
end

function show()
    ReplaceWallScreen({}):show()
end
