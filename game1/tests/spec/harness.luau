--!strict
local harness = {}

local passed = 0
local failed = 0

function harness.test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print("ok " .. name)
	else
		failed += 1
		print("not ok " .. name)
		print("  " .. tostring(err))
	end
end

function harness.assertEq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(
			(message or "not equal") .. ": " .. tostring(actual) .. " ~= " .. tostring(expected),
			2
		)
	end
end

function harness.assertTrue(value: any, message: string?)
	if value ~= true then
		error(message or "expected true", 2)
	end
end

function harness.assertFalse(value: any, message: string?)
	if value ~= false then
		error(message or "expected false", 2)
	end
end

function harness.finish()
	print(string.format("%d passed, %d failed", passed, failed))
	if failed > 0 then
		error(tostring(failed) .. " test(s) failed")
	end
end

return harness
