local selection = reqscript('internal/replace-wall/selection')

local function pos(x, y, z)
    return { x = x, y = y, z = z or 0 }
end

local function expect_positions(actual, expected)
    assert(#actual == #expected, ('expected %d tiles, got %d'):format(#expected, #actual))
    for index, expected_pos in ipairs(expected) do
        local actual_pos = actual[index]
        assert(actual_pos.x == expected_pos.x)
        assert(actual_pos.y == expected_pos.y)
        assert(actual_pos.z == expected_pos.z)
    end
end

expect_positions(selection.line(pos(2, 3), pos(2, 3)), { pos(2, 3) })
expect_positions(selection.line(pos(1, 1), pos(3, 1)), { pos(1, 1), pos(2, 1), pos(3, 1) })
expect_positions(selection.line(pos(1, 1), pos(3, 3)), { pos(1, 1), pos(2, 2), pos(3, 3) })
expect_positions(selection.area(pos(2, 2), pos(1, 1)), {
    pos(1, 1),
    pos(2, 1),
    pos(1, 2),
    pos(2, 2),
})
expect_positions(selection.line(pos(1, 1, 0), pos(1, 1, 1)), {})

print('replace-wall selection tests passed')
