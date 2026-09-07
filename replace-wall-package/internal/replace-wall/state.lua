--@ module = true

local config = reqscript('internal/replace-wall/config')

function normalize_material_token(token)
    if not token then
        return nil
    end

    token = string.upper(token)
    if not token:find(':', 1, true) and not dfhack.matinfo.find(token) then
        token = 'INORGANIC:' .. token
    end
    return token
end

function resolve_material(token)
    token = normalize_material_token(token)
    return token and dfhack.matinfo.find(token) or nil
end

function normalize_item_form(value)
    local requested = string.upper(tostring(value or ''))
    for name, form in pairs(config.ITEM_FORMS) do
        if form.aliases[requested] then
            return name
        end
    end

    return config.DEFAULT_ITEM_FORM
end

function get_item_form(value)
    local name = normalize_item_form(value)
    return name, config.ITEM_FORMS[name]
end

function material_is_valid(mat, item_form)
    local _, form = get_item_form(item_form)
    return form.accepts_material(mat)
end

function material_label(token)
    local mat = resolve_material(token)
    return mat and dfhack.capitalizeStringWords(mat.material.state_name.Solid) or tostring(token)
end

function default_state()
    return {
        version = config.STATE_VERSION,
        settings = {
            material_token = config.DEFAULT_MATERIAL_TOKEN,
            item_form = config.DEFAULT_ITEM_FORM,
        },
        plans = {},
    }
end

local function migrate(data)
    data.settings = type(data.settings) == 'table' and data.settings or {}
    local settings = data.settings

    settings.material_token = normalize_material_token(
        settings.material_token or settings.material_id
    ) or config.DEFAULT_MATERIAL_TOKEN

    settings.item_form = normalize_item_form(settings.item_form or settings.item_type)
    settings.material_id = nil
    settings.item_type = nil

    data.plans = type(data.plans) == 'table' and data.plans or {}
    data.version = config.STATE_VERSION

    return data
end

function load()
    if not dfhack.isSiteLoaded() then
        return default_state()
    end

    local data = dfhack.persistent.getSiteData(config.PERSIST_KEY, default_state())
    return migrate(type(data) == 'table' and data or default_state())
end

function save(data)
    data.version = config.STATE_VERSION
    dfhack.persistent.saveSiteData(config.PERSIST_KEY, data)
end

function record_material_token(record)
    local material = record.material or {}
    return normalize_material_token(material.token or material.id)
        or config.DEFAULT_MATERIAL_TOKEN
end

function record_item_form(record)
    local material = record.material or {}
    return normalize_item_form(material.item_form or material.item_type)
end
