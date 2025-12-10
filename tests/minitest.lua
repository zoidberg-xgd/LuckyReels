-- tests/minitest.lua
local MiniTest = {}

MiniTest.results = {
    passed = 0,
    failed = 0,
    logs = {}
}

local current_suite = "General"

function MiniTest.describe(name, callback)
    current_suite = name
    table.insert(MiniTest.results.logs, {type="suite", msg="Suite: " .. name})
    callback()
end

function MiniTest.it(name, callback)
    local status, err = pcall(callback)
    if status then
        MiniTest.results.passed = MiniTest.results.passed + 1
        table.insert(MiniTest.results.logs, {type="pass", msg="  ✔ " .. name})
    else
        MiniTest.results.failed = MiniTest.results.failed + 1
        table.insert(MiniTest.results.logs, {type="fail", msg="  ✘ " .. name .. " - " .. tostring(err)})
    end
end

function MiniTest.assert(condition, msg)
    if not condition then
        error(msg or "Assertion failed")
    end
end

function MiniTest.assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "Assertion failed") .. 
              ": expected " .. tostring(expected) .. 
              ", got " .. tostring(actual))
    end
end

function MiniTest.assertNil(value, msg)
    if value ~= nil then
        error((msg or "Expected nil") .. ", got " .. tostring(value))
    end
end

function MiniTest.assertNotNil(value, msg)
    if value == nil then
        error(msg or "Expected non-nil value")
    end
end

function MiniTest.assertType(value, expectedType, msg)
    if type(value) ~= expectedType then
        error((msg or "Type mismatch") .. 
              ": expected " .. expectedType .. 
              ", got " .. type(value))
    end
end

function MiniTest.assertThrows(fn, msg)
    local ok = pcall(fn)
    if ok then
        error(msg or "Expected function to throw")
    end
end

function MiniTest.run()
    -- Reset
    MiniTest.results.passed = 0
    MiniTest.results.failed = 0
    MiniTest.results.logs = {}
end

function MiniTest.runAll()
    local startTime = os.clock()
    
    for _, log in ipairs(MiniTest.results.logs) do
        if log.type == "pass" then
            print(log.msg)
            MiniTest.results.passed = MiniTest.results.passed + 1
        elseif log.type == "fail" then
            print(log.msg)
            MiniTest.results.failed = MiniTest.results.failed + 1
        end
    end
    
    local elapsed = os.clock() - startTime
    print(string.format("\n%d passed, %d failed (%.3fs)", 
        MiniTest.results.passed, MiniTest.results.failed, elapsed))
    
    -- Clear tests for next suite
    MiniTest.results = {
        passed = 0,
        failed = 0,
        logs = {}
    }
    
    return MiniTest.results.failed == 0
end

return MiniTest
