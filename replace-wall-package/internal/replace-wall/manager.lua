--@ module = true

local config = reqscript('internal/replace-wall/config')
local state = reqscript('internal/replace-wall/state')
local tiles = reqscript('internal/replace-wall/tiles')
local wall_builder = reqscript('internal/replace-wall/buildingplan')

running = running or false
generation = generation or 0

local function same_position(record, value)
    return record.x == value.x and record.y == value.y and record.z == value.z
end

local function inspect(record)
    local value = tiles.pos(record.x, record.y, record.z)
    local building = tiles.building_at(value)

    if building then
        return tiles.is_construction_wall(building) and 'remove' or 'keep'
    end

    if tiles.is_natural_wall(value) then
        return 'keep'
    end

    if tiles.is_floor(value) then
        local planned_wall, err = wall_builder.create_planned_wall(value, record)
        return planned_wall and 'remove' or 'keep', err
    end

    return 'keep', 'tile is no longer a natural wall or exposed floor'
end

function start()
    if running or not dfhack.isMapLoaded() then
        return
    end

    running = true
    generation = generation + 1
    local current_generation = generation

    dfhack.timeout(1, 'ticks', function()
        cycle(current_generation)
    end)
end

function stop()
    generation = generation + 1
    running = false
end

function cycle(current_generation)
    if current_generation ~= generation or not dfhack.isMapLoaded() then
        return
    end

    local data = state.load()
    local remaining = {}
    local handoffs = 0

    for _, record in ipairs(data.plans) do
        local action, err = 'keep'
        if handoffs < config.MAX_HANDOFFS_PER_CYCLE then
            action, err = inspect(record)
        end

        if action == 'remove' then
            handoffs = handoffs + 1
        else
            table.insert(remaining, record)
            if err then
                dfhack.printerr(('replace-wall (%d,%d,%d): %s'):format(
                    record.x, record.y, record.z, err
                ))
            end
        end
    end

    if #remaining ~= #data.plans then
        data.plans = remaining
        state.save(data)
    end

    if #remaining == 0 then
        running = false
        return
    end

    dfhack.timeout(config.MANAGER_INTERVAL, 'ticks', function()
        cycle(current_generation)
    end)
end

function resume()
    if not dfhack.isMapLoaded() then
        return
    end

    local data = state.load()
    local missing_designations = {}
    for _, record in ipairs(data.plans) do
        local value = tiles.pos(record.x, record.y, record.z)

        if tiles.is_natural_wall(value) and not tiles.is_mining_designated(value) then
            table.insert(missing_designations, value)
        end
    end

    local designation_success, designation_error = tiles.apply_mining(missing_designations, 'd')
    if not designation_success then
        dfhack.printerr('replace-wall could not restore mining designations: ' .. tostring(designation_error))
    end

    if #data.plans > 0 then
        start()
    end
end

function apply_selection(positions, mode)
    if #positions == 0 then
        return
    end

    local data = state.load()
    local plans_by_position = {}

    for _, record in ipairs(data.plans) do
        plans_by_position[tiles.key(record)] = record
    end

    if mode ~= 'erase' then
        local positions_to_designate = {}
        for _, value in ipairs(positions) do
            local key = tiles.key(value)
            if not plans_by_position[key] and tiles.is_natural_wall(value) then
                local record = {
                    x = value.x,
                    y = value.y,
                    z = value.z,
                    material = {
                        token = data.settings.material_token,
                        item_form = data.settings.item_form,
                    },
                }
                plans_by_position[key] = record

                table.insert(data.plans, record)
                table.insert(positions_to_designate, value)
            end
        end

        if #positions_to_designate > 0 then
            state.save(data)

            local designation_success, designation_error = tiles.apply_mining(positions_to_designate, 'd')
            if not designation_success then
                dfhack.printerr('replace-wall could not designate selection: ' .. tostring(designation_error))
            end

            start()
        end
        return
    end

    local positions_to_cancel = {}
    local positions_to_erase = {}

    for _, value in ipairs(positions) do
        local key = tiles.key(value)

        if plans_by_position[key] and tiles.is_natural_wall(value) then
            positions_to_erase[key] = true
            table.insert(positions_to_cancel, value)
        end
    end

    if #positions_to_cancel == 0 then
        return
    end

    local erase_success, erase_error = tiles.apply_mining(positions_to_cancel, 'x')
    if not erase_success then
        dfhack.printerr('replace-wall could not erase selection: ' .. tostring(erase_error))
        return
    end

    local remaining_plans = {}
    for _, record in ipairs(data.plans) do
        if not positions_to_erase[tiles.key(record)] then
            table.insert(remaining_plans, record)
        end
    end

    data.plans = remaining_plans
    state.save(data)
end

function find(data, value)
    for index, record in ipairs(data.plans) do
        if same_position(record, value) then
            return index
        end
    end
end
