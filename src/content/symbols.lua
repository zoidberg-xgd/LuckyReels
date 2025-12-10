-- src/content/symbols.lua
-- Data-driven symbol loading system
-- Symbols are defined in data/*.lua files for easy modding

local ContentLoader = require("src.core.content_loader")

-- Load base game symbols
local baseSymbols = require("data.symbols_base")
ContentLoader.loadSymbols(baseSymbols)

-- Load additional content packs (for modding/expansion)
-- Example: 
-- local expansion = require("data.symbols_expansion")
-- ContentLoader.loadSymbols(expansion)

print("[Symbols] Loaded " .. #(require("src.core.registry").getSymbolKeys and require("src.core.registry").getSymbolKeys() or {}) .. " symbols")

-- Legacy support: You can still define symbols directly here
-- local Registry = require("src.core.registry")
-- Registry.registerSymbol("custom_symbol", { ... })

-- Example of adding a custom symbol:
--[[
local Registry = require("src.core.registry")
Registry.registerSymbol("custom", {
    name_key = "symbol_custom_name",
    char = "自",
    color = {1, 0, 1},
    value = 2,
    rarity = 2,
    -- Use behavior templates:
    -- behavior = {type = "consume_adjacent", args = {"target_key", bonus, {r,g,b}}}
    -- Or custom function:
    on_calculate = function(self, grid, r, c)
        return self.base_value, {}, {}
    end
})
]]

-- Note: All symbols are now loaded from data/symbols_base.lua
-- You can add expansion packs by creating new data files
