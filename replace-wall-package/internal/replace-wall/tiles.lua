--@ module = true

local buildings = require('dfhack.buildings')
local quickfort = reqscript('quickfort')
local config = reqscript('internal/replace-wall/config')

function pos(x, y, z)
    return { x = x, y = y, z = z }
end

function key(value)
    return ('%d,%d,%d'):format(value.x, value.y, value.z)
end

function attrs(value)
    local tiletype = dfhack.maps.getTileType(value)
    return tiletype ~= nil and df.tiletype.attrs[tiletype] or nil
end

function is_natural_wall(value)
    local tile_attrs = attrs(value)
    return tile_attrs and tile_attrs.shape == df.tiletype_shape.WALL
        and tile_attrs.material ~= df.tiletype_material.CONSTRUCTION
end

function is_floor(value)
    local tile_attrs = attrs(value)
    return tile_attrs and tile_attrs.shape == df.tiletype_shape.FLOOR
end

function building_at(value)
    local ok, building = pcall(buildings.findAtTile, value)
    return ok and building or nil
end

function is_construction_wall(building)
    return building and building:getType() == df.building_type.Construction
        and building:getSubtype() == df.construction_type.Wall
end

function is_mining_designated(value)
    local designation = dfhack.maps.getTileFlags(value)
    return designation and designation.dig ~= df.tile_dig_designation.No
end

function apply_mining(positions, designation)
    if #positions == 0 then
        return true
    end
    local data = {}
    for _, value in ipairs(positions) do
        data[value.z] = data[value.z] or {}
        data[value.z][value.y] = data[value.z][value.y] or {}
        data[value.z][value.y][value.x] = designation
    end
    local ok, err = pcall(quickfort.apply_blueprint, {
        mode = 'dig',
        data = data,
        priority = config.MINING_PRIORITY,
        verbose = false,
    })
    return ok, err
end
