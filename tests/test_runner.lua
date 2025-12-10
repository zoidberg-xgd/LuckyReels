-- tests/test_runner.lua
-- Simple unit test framework

local TestRunner = {}
TestRunner.tests = {}
TestRunner.results = {passed = 0, failed = 0, errors = {}}

function TestRunner.describe(name, fn)
    print("\n=== " .. name .. " ===")
    fn()
end

function TestRunner.it(description, fn)
    local success, err = pcall(fn)
    if success then
        TestRunner.results.passed = TestRunner.results.passed + 1
        print("  ✓ " .. description)
    else
        TestRunner.results.failed = TestRunner.results.failed + 1
        table.insert(TestRunner.results.errors, {desc = description, err = err})
        print("  ✗ " .. description)
        print("    Error: " .. tostring(err))
    end
end

function TestRunner.assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function TestRunner.assertNotNil(value, message)
    if value == nil then
        error((message or "Assertion failed") .. ": expected non-nil value")
    end
end

function TestRunner.assertTrue(value, message)
    if not value then
        error((message or "Assertion failed") .. ": expected true")
    end
end

function TestRunner.assertFalse(value, message)
    if value then
        error((message or "Assertion failed") .. ": expected false")
    end
end

function TestRunner.assertApprox(actual, expected, tolerance, message)
    tolerance = tolerance or 0.001
    if math.abs(actual - expected) > tolerance then
        error((message or "Assertion failed") .. ": expected ~" .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

function TestRunner.assertTableEqual(actual, expected, message)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        error((message or "Assertion failed") .. ": both values must be tables")
    end
    for k, v in pairs(expected) do
        if actual[k] ~= v then
            error((message or "Assertion failed") .. ": key '" .. tostring(k) .. "' expected " .. tostring(v) .. ", got " .. tostring(actual[k]))
        end
    end
end

function TestRunner.printSummary()
    print("\n" .. string.rep("=", 50))
    print("Test Results: " .. TestRunner.results.passed .. " passed, " .. TestRunner.results.failed .. " failed")
    if #TestRunner.results.errors > 0 then
        print("\nFailed tests:")
        for _, err in ipairs(TestRunner.results.errors) do
            print("  - " .. err.desc)
        end
    end
    print(string.rep("=", 50))
    return TestRunner.results.failed == 0
end

function TestRunner.reset()
    TestRunner.results = {passed = 0, failed = 0, errors = {}}
end

return TestRunner
