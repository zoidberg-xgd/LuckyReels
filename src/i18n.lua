-- src/i18n.lua
local i18n = {}

i18n.current_lang = "zh" -- Default to Chinese
i18n.strings = {}
i18n.available_langs = {"zh", "en"}
i18n.lang_names = {
    zh = "中文",
    en = "English"
}

function i18n.load(lang)
    lang = lang or i18n.current_lang
    -- Clear cached module to allow reload
    package.loaded["src.locales." .. lang] = nil
    local ok, result = pcall(require, "src.locales." .. lang)
    if ok then
        i18n.strings = result
        i18n.current_lang = lang
        print("Loaded language: " .. lang)
    else
        print("Failed to load language: " .. lang)
        i18n.strings = {}
    end
end

function i18n.t(key, ...)
    -- Check main strings first
    local val = i18n.strings[key]
    
    -- Check mod-added translations (in i18n.locales)
    if not val and i18n.locales and i18n.locales[i18n.current_lang] then
        val = i18n.locales[i18n.current_lang][key]
    end
    
    -- Fallback to key
    val = val or key
    
    if select("#", ...) > 0 then
        return string.format(val, ...)
    end
    return val
end

-- Storage for mod-added translations
i18n.locales = {}

-- Set language (alias for load)
function i18n.setLanguage(lang)
    i18n.load(lang)
end

-- Get current language
function i18n.getLanguage()
    return i18n.current_lang
end

-- Toggle to next language
function i18n.nextLang()
    local currentIndex = 1
    for i, lang in ipairs(i18n.available_langs) do
        if lang == i18n.current_lang then
            currentIndex = i
            break
        end
    end
    local nextIndex = (currentIndex % #i18n.available_langs) + 1
    i18n.load(i18n.available_langs[nextIndex])
end

-- Get current language display name
function i18n.getCurrentLangName()
    return i18n.lang_names[i18n.current_lang] or i18n.current_lang
end

return i18n
