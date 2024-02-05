local	serial = require("serialization")
local	component = require("component")
local	robot = require("robot")
local	robot_ic = component.inventory_controller

local	circle = require("circle")

NORTH = 0
EAST = 1
SOUTH = 2
WEST = 3

local	diggy = {
	["pos"] = {["x"] = 0, ["y"] = 0, ["z"] = 70},
	["rdir"] = NORTH,
	["tool_slot"] = 3,
}

function	diggy.face(dir)
	if dir == diggy.rdir then
		return
	elseif dir == NORTH then
		if diggy.rdir == EAST then robot.turnLeft()
		elseif diggy.rdir == SOUTH then robot.turnAround()
		elseif diggy.rdir == WEST then robot.turnRight()
		end
	elseif dir == SOUTH then
		if diggy.rdir == WEST then robot.turnLeft()
		elseif diggy.rdir == NORTH then robot.turnAround()
		elseif diggy.rdir == EAST then robot.turnRight()
		end
	elseif dir == EAST then
		if diggy.rdir == SOUTH then robot.turnLeft()
		elseif diggy.rdir == WEST then robot.turnAround()
		elseif diggy.rdir == NORTH then robot.turnRight()
		end
	elseif dir == WEST then
		if diggy.rdir == NORTH then robot.turnLeft()
		elseif diggy.rdir == EAST then robot.turnAround()
		elseif diggy.rdir == SOUTH then robot.turnRight()
		end
	end
	diggy.rdir = dir
end

function	diggy.forward(_n)
	local	function step()
		local	retv, facing = robot.forward()

		if not retv then
			if facing == "solid" then
				diggy.swing()
				return step()
			elseif facing == "entity" then
				diggy.swing()
				require("computer").beep(1000, 1)
				return step()
			else
				print("error facing "..facing)
				return false
			end
		else
			return true
		end
	end
	local	n = _n or 1
	local	m = 0

	while n > 0 do
		if step() then
			n = n - 1
			m = m + 1
		end
	end
	return m
end

function	diggy.move(x, y)
	local	dx = x - diggy.pos.x
	local	dy = y - diggy.pos.y

	if dx > 0 then
		diggy.face(EAST)
	elseif 0 > dx then
		diggy.face(WEST)
		dx = dx * -1
	end
	diggy.forward(dx)

	if dy > 0 then
		diggy.face(NORTH)
	elseif 0 > dy then
		diggy.face(SOUTH)
		dy = dy * -1
	end
	diggy.forward(dy)

	diggy.pos.x = x
	diggy.pos.y = y
end


function	save_circle(c)
	local	point = io.open("circle_point", "w")
	point:write(serial.serialize(c))
	point:close()

	local	geo = io.open("circle_geo", "w")
	geo:write("{")
	for i, v in ipairs(c) do
		geo:write("("..v[1]..","..v[2]..")")
		if i ~= #c then geo:write(",") end
	end
	geo:write("}")
	geo:close()
end

function	diggy.select_item()
	for i = diggy.tool_slot + 1, 15 do
		if robot.count(i) > 2 then
			robot.select(i)
			return true
		end
	end
	return false
end

function	diggy.swing(side)
	local	swing = robot.swing

	if side == 1 then
		swing = robot.swingUp
	elseif side == 2 then
		swing = robot.swingDown
	end
	if swing() then
		return true
	end
	for i = 1, diggy.tool_slot do
		robot.select(i)
		robot_ic.equip()
		if swing() then
			return true
		end
	end
	return false
end

function	diggy.place(side)
	diggy.select_item()
	diggy.face(side)
	robot.place()
end

function	diggy.do_circle_perimeter(xc, yc, r)
	local	c = circle.get(xc, yc, r)

	for i, v in ipairs(c) do
		diggy.move(v[1], v[2])
		if circle.is_in(v[1] + 1, v[2], xc, yc, r) == false then
			diggy.place(EAST)
		end
		if circle.is_in(v[1] - 1, v[2], xc, yc, r) == false then
			diggy.place(WEST)
		end
		if circle.is_in(v[1], v[2] + 1, xc, yc, r) == false then
			diggy.place(NORTH)
		end
		if circle.is_in(v[1], v[2] - 1, xc, yc, r) == false then
			diggy.place(SOUTH)
		end
	end
end

-- MAIN

XC, YC, R = 0, 0, 5
DEPTH = 3
running = true

while running do
	if diggy.pos.z == DEPTH then running = false end

	diggy.do_circle_perimeter(XC, YC, R)

	r2 = R - 1
	while r2 > 0 do
		local	c = circle.get(XC, YC, r2)
		for i, v in ipairs(c) do
			diggy.move(v[1], v[2])
		end
		r2 = r2 - 1
	end
	diggy.move(XC, YC)
	diggy.swing(1)
	robot.down()
	diggy.pos.z = diggy.pos.z - 1
end
