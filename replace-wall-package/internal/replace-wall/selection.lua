--@ module = true

function line(start_pos, end_pos)
    if not start_pos or not end_pos or start_pos.z ~= end_pos.z then
        return {}
    end

    local tiles = {}

    local x, y = start_pos.x, start_pos.y

    local dx = math.abs(end_pos.x - x)
    local dy = -math.abs(end_pos.y - y)

    local sx = x < end_pos.x and 1 or -1
    local sy = y < end_pos.y and 1 or -1

    local err = dx + dy

    while true do
        table.insert(tiles, { x = x, y = y, z = start_pos.z })
        if x == end_pos.x and y == end_pos.y then
            break
        end

        local doubled_error = 2 * err
        if doubled_error >= dy then
            err = err + dy
            x = x + sx
        end

        if doubled_error <= dx then
            err = err + dx
            y = y + sy
        end
    end

    return tiles
end

function area(start_pos, end_pos)
    if not start_pos or not end_pos or start_pos.z ~= end_pos.z then
        return {}
    end

    local tiles = {}
    local min_x, max_x = math.min(start_pos.x, end_pos.x), math.max(start_pos.x, end_pos.x)
    local min_y, max_y = math.min(start_pos.y, end_pos.y), math.max(start_pos.y, end_pos.y)

    for y = min_y, max_y do
        for x = min_x, max_x do
            table.insert(tiles, { x = x, y = y, z = start_pos.z })
        end
    end

    return tiles
end

function preview(start_pos, end_pos, shape)
    return shape == 'area' and area(start_pos, end_pos) or line(start_pos, end_pos)
end
