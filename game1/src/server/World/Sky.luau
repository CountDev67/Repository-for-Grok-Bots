--!strict
-- Night lighting for the vampire theme. Every write is pcall-wrapped: some
-- Lighting properties are not script-writable, and those live in
-- default.project.json instead (Technology).

local Lighting = game:GetService("Lighting")

local Sky = {}

local rgb = Color3.fromRGB

local function set(object: Instance, props: { [string]: any })
	for key, value in props do
		local ok, err = pcall(function()
			(object :: any)[key] = value
		end)
		if not ok then
			warn(`[CountCrackula] skipped {object.ClassName}.{key}: {err}`)
		end
	end
end

local function fresh(className: string, name: string): Instance?
	local ok, result = pcall(function()
		for _, child in Lighting:GetChildren() do
			if child.ClassName == className then
				child:Destroy()
			end
		end
		local instance = Instance.new(className)
		instance.Name = name
		return instance
	end)
	if ok then
		return result
	end
	warn("[CountCrackula] could not create " .. className .. ": " .. tostring(result))
	return nil
end

function Sky.Apply()
	set(Lighting, {
		ClockTime = 0.4,
		Brightness = 1.8,
		Ambient = rgb(78, 66, 118),
		OutdoorAmbient = rgb(112, 98, 164),
		ColorShift_Top = rgb(130, 100, 210),
		ColorShift_Bottom = rgb(60, 20, 60),
		EnvironmentDiffuseScale = 0.45,
		EnvironmentSpecularScale = 0.7,
		ExposureCompensation = 0.25,
		GlobalShadows = true,
		FogColor = rgb(40, 20, 52),
		FogStart = 120,
		FogEnd = 1100,
		GeographicLatitude = 30,
	})

	local atmosphere = fresh("Atmosphere", "NightMist")
	if atmosphere then
		set(atmosphere, {
			Density = 0.27,
			Offset = 0.08,
			Color = rgb(86, 62, 138),
			Decay = rgb(70, 24, 60),
			Glare = 0,
			Haze = 1.3,
		})
		atmosphere.Parent = Lighting
	end

	local sky = fresh("Sky", "NightSky")
	if sky then
		set(sky, {
			StarCount = 3500,
			CelestialBodiesShown = true,
			MoonAngularSize = 16,
		})
		sky.Parent = Lighting
	end

	local bloom = fresh("BloomEffect", "NeonBloom")
	if bloom then
		set(bloom, { Intensity = 0.7, Size = 28, Threshold = 1.3 })
		bloom.Parent = Lighting
	end

	local grade = fresh("ColorCorrectionEffect", "MoonGrade")
	if grade then
		set(grade, {
			TintColor = rgb(232, 218, 255),
			Saturation = 0.12,
			Contrast = 0.12,
			Brightness = 0.03,
		})
		grade.Parent = Lighting
	end
end

return Sky
