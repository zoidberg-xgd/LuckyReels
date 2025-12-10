-- data/consumables_base.lua
-- Base game consumables - data driven definition

local Registry = require("src.core.registry")

return {
    removal_token = {
        name_key = "item_removal_token_name",
        desc_key = "item_removal_token_desc",
        char = "删",
        color = {1, 0.3, 0.3},
        on_use = function(self, engine)
            if engine.state == "IDLE" then
                engine.state = "REMOVING"
                return false 
            end
            return false
        end
    },
    
    reroll_token = {
        name_key = "item_reroll_name",
        desc_key = "item_reroll_desc",
        char = "换",
        color = {0.3, 0.7, 1},
        on_use = function(self, engine)
            if engine.state == "IDLE" then
                engine.grid:spin(engine.inventory)
                return true
            end
            return false
        end
    },
    
    coin_bag = {
        name_key = "item_coin_bag_name",
        desc_key = "item_coin_bag_desc",
        char = "袋",
        color = {1, 0.85, 0.2},
        on_use = function(self, engine)
            engine.money = engine.money + 10
            return true
        end
    },
    
    extra_spin = {
        name_key = "item_extra_spin_name",
        desc_key = "item_extra_spin_desc",
        char = "转",
        color = {0.5, 1, 0.5},
        on_use = function(self, engine)
            engine.spins_left = engine.spins_left + 1
            return true
        end
    },
    
    lucky_charm = {
        name_key = "item_lucky_charm_name",
        desc_key = "item_lucky_charm_desc",
        char = "运",
        color = {1, 0.9, 0.3},
        on_use = function(self, engine)
            engine.temp_bonus = (engine.temp_bonus or 0) + 10
            return true
        end
    },
    
    symbol_copy = {
        name_key = "item_copy_name",
        desc_key = "item_copy_desc",
        char = "复",
        color = {0.7, 0.5, 1},
        on_use = function(self, engine)
            if #engine.inventory > 0 then
                local idx = math.random(#engine.inventory)
                local sym = engine.inventory[idx]
                local copy = Registry.createSymbol(sym.key)
                copy.level = sym.level
                copy.base_value = sym.base_value
                table.insert(engine.inventory, copy)
                return true
            end
            return false
        end
    },
    
    upgrade_token = {
        name_key = "item_upgrade_name",
        desc_key = "item_upgrade_desc",
        char = "升",
        color = {0.9, 0.7, 0.2},
        on_use = function(self, engine)
            if #engine.inventory > 0 then
                local idx = math.random(#engine.inventory)
                local sym = engine.inventory[idx]
                sym.level = (sym.level or 1) + 1
                sym.base_value = sym.base_value * 2
                return true
            end
            return false
        end
    },
    
    time_warp = {
        name_key = "item_time_warp_name",
        desc_key = "item_time_warp_desc",
        char = "时",
        color = {0.5, 0.8, 0.9},
        on_use = function(self, engine)
            engine.spins_left = engine.spins_max
            return true
        end
    },
}
