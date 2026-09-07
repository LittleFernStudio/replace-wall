--@ module = true

PERSIST_KEY = 'replace-wall'
STATE_VERSION = 7
MANAGER_INTERVAL = 100
MINING_PRIORITY = 4
MAX_HANDOFFS_PER_CYCLE = 50
DEFAULT_MATERIAL_TOKEN = 'INORGANIC:MARBLE'
DEFAULT_ITEM_FORM = 'BLOCKS'

ITEM_FORMS = {
    BLOCKS = {
        label = 'Blocks',
        aliases = { BLOCK = true, BLOCKS = true },
        item_type = df.item_type.BLOCKS,
        vector_id = df.job_item_vector_id.BLOCKS,
        accepts_material = function(mat)
            return mat.flags.IS_STONE or mat.flags.IS_METAL or mat.flags.IS_GLASS or mat.flags.WOOD
        end,
    },
    BOULDER = {
        label = 'Boulders',
        aliases = { BOULDER = true, BOULDERS = true, ROCK = true },
        item_type = df.item_type.BOULDER,
        vector_id = df.job_item_vector_id.BOULDER,
        accepts_material = function(mat)
            return mat.flags.IS_STONE
        end,
    },
}
