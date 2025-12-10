#!/usr/bin/env lua
--[[
    GameLib 测试运行器
    
    运行: lua lib/gamelib/test_all.lua
]]

-- 设置路径
local scriptPath = debug.getinfo(1, "S").source:match("@(.*/)")
if scriptPath then
    package.path = scriptPath .. "../../?.lua;" .. package.path
end

print("========================================")
print("GameLib Test Suite")
print("========================================\n")

local totalPassed = 0
local totalFailed = 0

local tests = {
    "tests/test_resource",
    "tests/test_state_sprite",
    "tests/test_proc_shape",
    "tests/test_interact_region",
    "tests/test_dialogue",
    "tests/test_weighted_event",
    "tests/test_ecs",
}

for _, testPath in ipairs(tests) do
    print("\n--- Running: " .. testPath .. " ---\n")
    
    -- 清除缓存以重新加载
    package.loaded[testPath] = nil
    
    local ok, result = pcall(require, testPath)
    if ok and result then
        totalPassed = totalPassed + (result.passed or 0)
        totalFailed = totalFailed + (result.failed or 0)
    else
        print("Error loading test: " .. tostring(result))
        totalFailed = totalFailed + 1
    end
end

print("\n========================================")
print("TOTAL RESULTS")
print("========================================")
print(string.format("Passed: %d", totalPassed))
print(string.format("Failed: %d", totalFailed))
print(string.format("Total:  %d", totalPassed + totalFailed))
print("========================================")

if totalFailed > 0 then
    os.exit(1)
else
    print("\n✓ All tests passed!")
    os.exit(0)
end
