local	circle = {
	["octant"] = {},
	["cache"] = {},
}

function	circle.get(xc, yc, r)
	local	c_key = xc..","..yc..":"..r
	if circle.cache[c_key] then return circle.cache[c_key] end

	local	o = circle.octant.get(xc, yc, r)
	local	c = o[1]

	for i = #o[2], 1, -1 do c[#c + 1] = o[2][i] end

	for i = 1, #o[3] do c[#c + 1] = o[3][i] end
	for i = #o[4], 1, -1 do c[#c + 1] = o[4][i] end

	for i = 1, #o[5] do c[#c + 1] = o[5][i] end
	for i = #o[6], 1, -1 do c[#c + 1] = o[6][i] end

	for i = 1, #o[7] do c[#c + 1] = o[7][i] end
	for i = #o[8], 1, -1 do c[#c + 1] = o[8][i] end

	circle.cache[c_key] = circle.clean(c)
	return circle.cache[c_key]
end

function	circle.octant.get(xc, yc, r)
	local	o = {{}, {}, {}, {}, {}, {}, {}, {}}
	local	t1 = r / 16

	local	t2 = 0
	local	x = r
	local	y = 0
	-- local	rounded = false

	while x >= y do
		circle.octant.add(o, xc, x, yc, y)
		y = y + 1
		t1 = t1 + y
		t2 = t1 - x
		if t2 >= 0 then
			t1 = t2
			circle.octant.add(o, xc, x - 1, yc, y - 1)
			x = x - 1
		end
	end
	return o
end

function	circle.octant.add(o, xc, x, yc, y)
	o[1][#o[1] + 1] = {xc + x, yc + y}
	o[2][#o[2] + 1] = {xc + y, yc + x}
	o[3][#o[3] + 1] = {xc - y, yc + x}
	o[4][#o[4] + 1] = {xc - x, yc + y}
	o[5][#o[5] + 1] = {xc - x, yc - y}
	o[6][#o[6] + 1] = {xc - y, yc - x}
	o[7][#o[7] + 1] = {xc + y, yc - x}
	o[8][#o[8] + 1] = {xc + x, yc - y}
end

function	circle.clean(c)
	local	cleaned = {}
	local	founded = false

	for i, v in ipairs(c) do
		for ii, vv in ipairs(cleaned) do
			if vv[1] == v[1] and vv[2] == v[2] then founded = true end
		end
		if founded == false then
			cleaned[#cleaned + 1] = v
		end
		founded = false
	end
	return cleaned
end

function circle.is_in(x, y, xc, yc, r)
	local	xx, yy = x - xc, y - yc
	if math.sqrt((xx * xx) + (yy * yy)) < r then return true end

	local	c = circle.get(xc, yc, r)
	for i, v in ipairs(c) do
		if v[1] == x and v[2] == y then return true end
	end
	return false
end

return circle