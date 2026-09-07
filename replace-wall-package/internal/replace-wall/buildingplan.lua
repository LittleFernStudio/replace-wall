--@ module = true

local buildings = require('dfhack.buildings')
local buildingplan = require('plugins.buildingplan')
local config = reqscript('internal/replace-wall/config')
local state = reqscript('internal/replace-wall/state')
local tiles = reqscript('internal/replace-wall/tiles')

local WALL_TYPE = df.building_type.Construction
local WALL_SUBTYPE = df.construction_type.Wall
local WALL_CUSTOM = -1
local FILTER_INDEX = 0

local function snapshot_filter()
    local materials = buildingplan.getMaterialFilter(
        WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM, FILTER_INDEX
    )

    local mask = buildingplan.getMaterialMaskFilter(
        WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM, FILTER_INDEX
    )

    local snapshot = { material_names = {}, categories = {}, mask_unset = true }
    for name, properties in pairs(materials or {}) do
        if properties and properties.enabled == 'true' then
            table.insert(snapshot.material_names, name)
        end
    end

    if mask then
        snapshot.mask_unset = mask.unset == true
        for category, enabled in pairs(mask) do
            if category ~= 'unset' and enabled == true then
                table.insert(snapshot.categories, category)
            end
        end
    end
    return snapshot
end

local function set_filter(mat)
    local name = mat:toString()
    if not name or name == '' then
        return nil, 'could not determine the Buildingplan material name'
    end

    buildingplan.setMaterialFilter(WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM, FILTER_INDEX, { name })
    return name
end

local function restore_filter(snapshot)
    local materials = snapshot.mask_unset and {} or snapshot.material_names
    local categories = snapshot.mask_unset and {} or snapshot.categories
    buildingplan.setMaterialFilter(WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM, FILTER_INDEX, materials)
    buildingplan.setMaterialMaskFilter(
        WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM, FILTER_INDEX, categories
    )
end

function create_planned_wall(value, record)
    local material_token = state.record_material_token(record)
    local mat = state.resolve_material(material_token)

    if not mat then
        return nil, 'could not resolve material ' .. tostring(material_token)
    end

    local existing = tiles.building_at(value)
    if existing then
        return tiles.is_construction_wall(existing) and existing or nil,
            tiles.is_construction_wall(existing) and nil or 'another building occupies this tile'
    end

    local _, item_form = state.get_item_form(state.record_item_form(record))
    local filters = buildings.getFiltersByType({}, WALL_TYPE, WALL_SUBTYPE, WALL_CUSTOM)

    if not filters or not filters[1] then
        return nil, 'could not obtain wall construction filters'
    end
    filters[1].item_type = item_form.item_type
    filters[1].item_subtype = -1
    filters[1].vector_id = item_form.vector_id

    -- Buildingplan keeps material preferences globally, so preserve the player's filter.
    local snapshot_succeeded, snapshot_filter_or_error = pcall(snapshot_filter)

    if not snapshot_succeeded then
        return nil, 'could not read the Buildingplan material filter: ' .. tostring(snapshot_filter_or_error)
    end

    local filter_set_succeeded, material_name, filter_error = pcall(set_filter, mat)

    if not filter_set_succeeded or not material_name then
        pcall(restore_filter, snapshot_filter_or_error)
        return nil, 'could not set the Buildingplan material: '
            .. tostring(filter_set_succeeded and filter_error or material_name)
    end

    local building, construction_error = buildings.constructBuilding({
        pos = tiles.pos(value.x, value.y, value.z),
        type = WALL_TYPE,
        subtype = WALL_SUBTYPE,
        filters = filters,
    })

    if not building then
        pcall(restore_filter, snapshot_filter_or_error)
        return nil, 'constructBuilding failed: ' .. tostring(construction_error)
    end

    local planning_succeeded, plan_result_or_error = pcall(buildingplan.addPlannedBuilding, building)
    local restore_succeeded, restore_error = pcall(restore_filter, snapshot_filter_or_error)

    if not restore_succeeded then
        local message = 'replace-wall could not restore the Buildingplan filter: '
            .. tostring(restore_error)
        dfhack.printerr(message)
    end

    if not planning_succeeded then
        return nil, 'addPlannedBuilding failed: ' .. tostring(plan_result_or_error)
    end

    if plan_result_or_error == false or not buildingplan.isPlannedBuilding(building) then
        return nil, 'Buildingplan did not retain ownership'
    end

    buildingplan.scheduleCycle()
    return building
end
