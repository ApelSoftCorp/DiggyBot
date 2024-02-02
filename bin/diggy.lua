local	serial = require("serialization")
-- local	robot = require("robot")
robot = {}

local	circle = require("circle")

NORTH = 0
EAST = 1
SOUTH = 2
WEST = 3

local	diggy = {
	["pos"] = {["x"] = 0, ["y"] = 0, ["z"] = 70},
	["rdir"] = NORTH,
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

function	diggy.move(x, y)
	local	dx = x - robot.pos.x
	local	dy = y - robot.pos.y

	if dx > 0 then
		diggy.face(EAST)
	elseif 0 > dx then
		diggy.face(WEST)
		dx = dx * -1
	end
	while dx > 0 do
		if not robot.forward() then
			robot.swing()
			robot.forward()
		end
		dx = dx - 1
	end
	if dy > 0 then
		diggy.face(NORTH)
	elseif 0 > dy then
		diggy.face(SOUTH)
		dy = dy * -1
	end
	while dy > 0 do
		if not robot.forward() then
			robot.swing()
			robot.forward()
		end
		dy = dy - 1
	end

	robot.pos.x = x
	robot.pos.y = y
end

function	diggy.do_circle_perimeter(c)
	for i, v in ipairs(c) do
		robot.move(v[1], v[2])
	end
end


-- MAIN

PX, PY, R = 0, 0, 6

c = circle.get(PX, PY, R)

local	file = io.open("last_circle", "w")
file:write(serial.serialize(c))
file:close()

local	geo = io.open("geo", "w")
geo:write("{")

for i, v in ipairs(c) do
	geo:write("("..v[1]..","..v[2]..")")
	if i ~= #c then geo:write(",") end
end
geo:write("}")
geo:close()



-- while true do
-- 	local	tmp_R = R
-- 	while tmp_R > 0 do
-- 		C = circle.get(PX, PY, tmp_R)
-- 		robot.do_circle_perimeter(C)
-- 		tmp_R = tmp_R - 1
-- 	end

-- 	diggy.move(PX, PY)
-- 	robot.swingDown()
-- 	robot.down()
-- 	robot.pos.z = robot.pos.z - 1
-- 	require("computer").beep(1000)
-- end
