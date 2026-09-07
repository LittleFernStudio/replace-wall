--@ module = true

local overlay = require('plugins.overlay')
local guidm = require('gui.dwarfmode')
local state = reqscript('internal/replace-wall/state')
local tiles = reqscript('internal/replace-wall/tiles')

-- Texture handles survive DF texture-table resets; raw texpos values do not.
local textures =
    dfhack.textures.loadTileset(dfhack.getHackPath() .. '/data/art/replace_wall.png', 32, 32, true)
local WALL_MARKER = textures[1]

local function is_visible()
    return dfhack.screen.inGraphicsMode()
        or dfhack.gui.matchFocusString('dwarfmode/Default', dfhack.gui.getDFViewscreen(true))
end

ReplaceWallOverlay = defclass(ReplaceWallOverlay, overlay.OverlayWidget)
ReplaceWallOverlay.ATTRS({
    desc = 'Marks natural walls pending replacement.',
    default_enabled = true,
    viewscreens = { 'dwarfmode' },
    frame = { w = 0, h = 0 },
    visible = is_visible,
    overlay_onupdate_max_freq_seconds = 0.25,
})

function ReplaceWallOverlay:init()
    self.pending_tiles = {}
end

function ReplaceWallOverlay:overlay_onupdate()
    self.pending_tiles = {}

    if not dfhack.isMapLoaded() or not dfhack.isSiteLoaded() then
        return
    end

    for _, record in ipairs(state.load().plans) do
        local value = tiles.pos(record.x, record.y, record.z)

        if tiles.is_natural_wall(value) then
            table.insert(self.pending_tiles, value)
        end
    end
end

function ReplaceWallOverlay:onRenderFrame(dc)
    if not self.pending_tiles then
        return
    end

    if not df.global.pause_state and not dfhack.screen.inGraphicsMode() then
        return
    end

    local viewport = guidm.Viewport.get()
    local texture = dfhack.textures.getTexposByHandle(WALL_MARKER)
    if not viewport or not texture then
        return
    end

    dc:map(true)
    for _, value in ipairs(self.pending_tiles) do
        if viewport:isVisible(value) then
            local screen_pos = viewport:tileToScreen(value)
            dc:seek(screen_pos.x, screen_pos.y):tile('X', texture, COLOR_LIGHTBLUE)
        end
    end
    dc:map(false)
end

OVERLAY_WIDGETS = { pending = ReplaceWallOverlay }
