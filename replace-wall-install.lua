local PACKAGE_DIR = dfhack.getHackPath() .. '/scripts/replace-wall-package'
local INIT_FILE = dfhack.getDFPath() .. '/dfhack-config/init/dfhack.init'
local KEYBINDING = 'keybinding add Ctrl-Shift-R@dwarfmode/Default "replace-wall paint"'

local FILES = {
    { source = 'replace-wall.lua',         destination = 'scripts/replace-wall.lua' },
    { source = 'replace-wall-overlay.lua', destination = 'scripts/replace-wall-overlay.lua' },
    {
        source = 'internal/replace-wall/buildingplan.lua',
        destination = 'scripts/internal/replace-wall/buildingplan.lua'
    },
    {
        source = 'internal/replace-wall/config.lua',
        destination = 'scripts/internal/replace-wall/config.lua'
    },
    {
        source = 'internal/replace-wall/manager.lua',
        destination = 'scripts/internal/replace-wall/manager.lua'
    },
    {
        source = 'internal/replace-wall/selection.lua',
        destination = 'scripts/internal/replace-wall/selection.lua'
    },
    {
        source = 'internal/replace-wall/selection-test.lua',
        destination = 'scripts/internal/replace-wall/selection-test.lua'
    },
    {
        source = 'internal/replace-wall/state.lua',
        destination = 'scripts/internal/replace-wall/state.lua'
    },
    {
        source = 'internal/replace-wall/tiles.lua',
        destination = 'scripts/internal/replace-wall/tiles.lua'
    },
    {
        source = 'internal/replace-wall/ui.lua',
        destination = 'scripts/internal/replace-wall/ui.lua'
    },
    {
        source = 'internal/replace-wall/README.md',
        destination = 'scripts/internal/replace-wall/README.md'
    },
    { source = 'replace_wall.png', destination = 'data/art/replace_wall.png' },
}

local function join(root, relative_path)
    return root .. '/' .. relative_path
end

local function parent_directory(path)
    return path:match('^(.*)[/\\][^/\\]+$')
end

local function copy_file(source, destination)
    local input, read_error = io.open(source, 'rb')

    if not input then
        return false, read_error
    end

    local contents = input:read('*a')
    input:close()

    local parent = parent_directory(destination)
    if parent and not dfhack.filesystem.mkdir_recursive(parent) then
        return false, 'could not create ' .. parent
    end

    local output, write_error = io.open(destination, 'wb')

    if not output then
        return false, write_error
    end

    output:write(contents)
    output:close()

    return true
end

local function remove_directory(path)
    for _, name in ipairs(dfhack.filesystem.listdir(path)) do
        local child = join(path, name)

        if dfhack.filesystem.isdir(child) then
            local removed, remove_error = remove_directory(child)

            if not removed then
                return false, remove_error
            end
        elseif not os.remove(child) then
            return false, 'could not remove ' .. child
        end
    end

    if not dfhack.filesystem.rmdir(path) then
        return false, 'could not remove ' .. path
    end

    return true
end

local function install_keybinding()
    local contents = ''
    local input = io.open(INIT_FILE, 'r')

    if input then
        contents = input:read('*a')
        input:close()
    end

    if contents:find(KEYBINDING, 1, true) then
        return false
    end

    local parent = parent_directory(INIT_FILE)
    if parent and not dfhack.filesystem.mkdir_recursive(parent) then
        qerror('Could not create the DFHack init directory: ' .. parent)
    end

    local output, write_error = io.open(INIT_FILE, 'a')
    if not output then
        qerror('Could not update ' .. INIT_FILE .. ': ' .. tostring(write_error))
    end

    if contents ~= '' and not contents:match('\n$') then
        output:write('\n')
    end

    output:write(KEYBINDING .. '\n')
    output:close()

    return true
end

local function show_help()
    print([[
replace-wall-install
Usage:
  replace-wall-install
  replace-wall-install --force

The default installation skips files that already exist. Use --force to update an existing
installation. The temporary replace-wall-package directory is removed after a successful install.
]])
end

local function main(...)
    local arguments = { ... }
    if arguments[1] == 'help' or arguments[1] == '-h' or arguments[1] == '--help' then
        show_help()
        return
    end

    local overwrite = arguments[1] == '--force'

    if arguments[1] and not overwrite then
        qerror('Unknown option: ' .. tostring(arguments[1]))
    end

    if not dfhack.filesystem.isdir(PACKAGE_DIR) then
        qerror('Package directory not found: ' .. PACKAGE_DIR)
    end

    local installed, skipped = 0, 0
    for _, file in ipairs(FILES) do
        local source = join(PACKAGE_DIR, file.source)
        local destination = join(dfhack.getHackPath(), file.destination)

        if not dfhack.filesystem.isfile(source) then
            qerror('Package is incomplete. Missing: ' .. source)
        end

        if dfhack.filesystem.exists(destination) and not overwrite then
            print('Skipping existing file: ' .. destination)
            skipped = skipped + 1
        else
            local copied, copy_error = copy_file(source, destination)

            if not copied then
                qerror('Could not install ' .. destination .. ': ' .. tostring(copy_error))
            end

            print('Installed: ' .. destination)
            installed = installed + 1
        end
    end

    local keybinding_added = install_keybinding()
    local cleaned, cleanup_error = remove_directory(PACKAGE_DIR)

    if not cleaned then
        qerror('Installation succeeded, but cleanup failed: ' .. tostring(cleanup_error))
    end

    print(('Replace Wall installation complete: %d installed, %d skipped.'):format(
        installed, skipped
    ))
    print(keybinding_added and 'Added Ctrl-Shift-R shortcut.'
        or 'Ctrl-Shift-R shortcut is already configured.')
    print('Removed temporary replace-wall-package directory.')
    print('Restart Dwarf Fortress before using replace-wall so the texture is reloaded.')
    print("Start it with Ctrl+Shift+R or run 'replace-wall paint' in the DFHack console.")
end

main(...)
