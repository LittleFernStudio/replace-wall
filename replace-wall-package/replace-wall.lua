--@ module = true

local config = reqscript('internal/replace-wall/config')
local manager = reqscript('internal/replace-wall/manager')
local state = reqscript('internal/replace-wall/state')
local ui = reqscript('internal/replace-wall/ui')

local function show_status()
    local data = state.load()
    local _, item_form = state.get_item_form(data.settings.item_form)

    print('replace-wall status')
    print('  material: ' .. state.material_label(data.settings.material_token))
    print('  item form: ' .. item_form.label)
    print('  pending plans: ' .. tostring(#data.plans))
    print('  manager running: ' .. tostring(manager.running))
end

local function set_material(token)
    if not token then
        local data = state.load()
        local material = state.material_label(data.settings.material_token)

        print('Current replace-wall material: ' .. material)
        return
    end

    local mat = state.resolve_material(token)
    local data = state.load()
    if not mat or not state.material_is_valid(mat.material, data.settings.item_form) then
        qerror('Material cannot be used for the selected item form: ' .. tostring(token))
    end

    data.settings.material_token = mat:getToken()
    state.save(data)

    print('replace-wall material set to ' .. state.material_label(data.settings.material_token))
end

local function set_item_form(value)
    if not value then
        local data = state.load()
        local _, form = state.get_item_form(data.settings.item_form)

        print('Current replace-wall item form: ' .. form.label)
        return
    end

    local requested = string.upper(value)
    local valid = config.ITEM_FORMS.BLOCKS.aliases[requested]
        or config.ITEM_FORMS.BOULDER.aliases[requested]

    if not valid then
        qerror('Item form must be blocks or boulders.')
    end

    local data = state.load()
    data.settings.item_form = state.normalize_item_form(value)

    local mat = state.resolve_material(data.settings.material_token)
    if not mat or not state.material_is_valid(mat.material, data.settings.item_form) then
        data.settings.material_token = config.DEFAULT_MATERIAL_TOKEN
    end
    state.save(data)

    local _, form = state.get_item_form(data.settings.item_form)

    print('replace-wall item form set to ' .. form.label)
end

local function show_help()
    print([[
replace-wall
Usage:
  replace-wall [paint]
  replace-wall material [TOKEN]
  replace-wall form [blocks|boulders]
  replace-wall resume
  replace-wall status
Controls:
  Left-click/drag       add a straight line
  Ctrl+Left-click/drag  erase a straight line
  Shift+Left-click/drag add a rectangular area
  Ctrl+Shift+drag       erase a rectangular area
  M                     select material
  B                     switch item form
  Esc / Right-click     close painting mode
]])
end

local STATE_CHANGE_KEY = 'replace-wall-manager'
dfhack.onStateChange[STATE_CHANGE_KEY] = function(code)
    if code == SC_MAP_LOADED then
        dfhack.timeout(1, 'ticks', manager.resume)
    elseif code == SC_MAP_UNLOADED then
        manager.stop()
    end
end

-- Reloading a script does not emit SC_MAP_LOADED for a map that is already open.
if dfhack.isMapLoaded() then
    manager.resume()
end

local function main(...)
    local args = { ... }
    local command = args[1]
    if not command or command == 'paint' then
        if not dfhack.isMapLoaded() then
            qerror('A fortress map must be loaded.')
        end
        ui.show()
    elseif command == 'material' then
        set_material(args[2])
    elseif command == 'form' or command == 'item' then
        set_item_form(args[2])
    elseif command == 'resume' then
        manager.resume()
    elseif command == 'status' then
        show_status()
    elseif command == 'help' or command == '-h' or command == '--help' then
        show_help()
    else
        qerror('Unknown replace-wall command: ' .. tostring(command))
    end
end

if not dfhack_flags.module then
    main(...)
end
