local	serial = require("serialization")
local	component = require("component")
local	computer = require("computer")
local	robot = require("robot")
local	robot_ic = component.inventory_controller
local	chat = component.chat

local	circle = require("circle")

DIGGY_NAME = "DiggyBot"
DIGGY_MSG = "I am dward and i'm diggin an hole, DIGGY DIGGY HOLE, DIGGY DIGGY HOLE"
QUIET = false

NORTH = 0
EAST = 1
SOUTH = 2
WEST = 3
RIGHT = 4
LEFT = 5

local	diggy = {
	["pos"] = {["x"] = 0, ["y"] = 0, ["z"] = 237},
	["last_pos"] = {["x"] = 0, ["y"] = 0, ["z"] = 0},
	["rdir"] = NORTH,
	["tool_slot"] = 0,
	["tool_stock"] = 2,
	["full_threshold"] = 2,
	["energy_threshold"] = 15,
	["need_energy"] = false,
	["need_deposit"] = false,
	["need_tool"] = false,
}

-- function	gpos(x, y, z)
-- 	if z then return "("..x..","..y..","..z..")"
-- 	else return "("..x..","..y..")"
-- 	end
-- end

function	get_random_list(len)
	local	l = {}
	local	f = io.open("/dev/random", "rb")

	function	get_random_number(n)
		return string.byte(f:read(1)) % n
	end

	function	get_random_number_not_in(len)
		local	r = get_random_number(len)
		for i, v in ipairs(l) do if v == r then
			return get_random_number_not_in(len)
		end end
		return r
	end

	for i = 1, len do
		l[i] = get_random_number_not_in(len)
	end
	f:close()
	return l
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
	for i = (diggy.tool_slot * diggy.tool_stock) + 1, 15 do
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
	for i = 1, diggy.tool_slot * diggy.tool_stock, 2 do
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
		diggy.move(v[1], v[2], diggy.pos.z, false)
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

function	diggy.get_face(dir)
	if dir == RIGHT then
		if diggy.rdir == NORTH then return EAST
		elseif diggy.rdir == SOUTH then return WEST
		elseif diggy.rdir == EAST then return SOUTH
		elseif diggy.rdir == WEST then return NORTH
		end
	elseif dir == LEFT then
		if diggy.rdir == NORTH then return WEST
		elseif diggy.rdir == SOUTH then return EAST
		elseif diggy.rdir == EAST then return NORTH
		elseif diggy.rdir == WEST then return SOUTH
		end
	end
end

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
	elseif dir == RIGHT then
		diggy.face(diggy.get_face(RIGHT))
		return
	elseif dir == LEFT then
		diggy.face(diggy.get_face(LEFT))
		return
	end
	diggy.rdir = dir
end

local	function change_dir(d)
	if d == 0 and robot.detectUp() == false then
		return diggy.step(1, true)
	elseif d == 1 and robot.detectDown() == false then
		return diggy.step(2, true)
	elseif d == 2 then
		diggy.face(RIGHT)
		if robot.detect() == false then
			local	retv = diggy.step(0, true)
			diggy.face(LEFT)
			return retv
		end
		diggy.face(LEFT)
	elseif d == 3 then
		diggy.face(LEFT)
		if robot.detect() == false then
			local	retv = diggy.step(0, true)
			diggy.face(RIGHT)
			return retv
		end
		diggy.face(RIGHT)
	end
	return false
end

function	diggy.change_dir(opposed_dir)
	for i, v in ipairs(get_random_list(4)) do
		if v ~= opposed_dir then
			if change_dir(v) then
				return true
			end
		end
	end
	return false
end

function	diggy.step(dir, soft)
	local	step_func = robot.forward

	if dir == 1 then
		step_func = robot.up
	elseif dir == 2 then
		step_func = robot.down
	end
	local	retv, facing = step_func()

	if not retv then
		if facing == "entity" then
			diggy.swing(dir)
			computer.beep(1000, 1)
			return diggy.step(dir, soft)
		elseif facing == "solid" and soft == false then
			diggy.swing(dir)
			return diggy.step(dir, soft)
		end
		return false
	end
	if dir == 1 then
		diggy.pos.z = diggy.pos.z + 1
	elseif dir == 2 then
		diggy.pos.z = diggy.pos.z - 1
	else
		if diggy.rdir == EAST then
			diggy.pos.x = diggy.pos.x + 1
		elseif diggy.rdir == WEST then
			diggy.pos.x = diggy.pos.x - 1
		elseif diggy.rdir == NORTH then
			diggy.pos.y = diggy.pos.y + 1
		elseif diggy.rdir == SOUTH then
			diggy.pos.y = diggy.pos.y - 1
		end
	end
	return true
end

function	diggy.move(x, y, z, soft)
	local	z = z or diggy.pos.z
	local	dx = x - diggy.pos.x
	local	dy = y - diggy.pos.y
	local	dz = z - diggy.pos.z

	function	move_x()
		if dx > 0 then
			diggy.face(EAST)
		elseif 0 > dx then
			diggy.face(WEST)
			dx = dx * -1
			opposed_dir = -1
		end

		while dx > 0 do
			if diggy.step(0, soft) == false then
				local	retv = diggy.change_dir()
				if retv == false then
					print("Error changing dir")
				end
			end
			dx = dx - 1
		end
	end

	function	move_y()
		if dy > 0 then
			diggy.face(NORTH)
		elseif 0 > dy then
			diggy.face(SOUTH)
			dy = dy * -1
		end

		while dy > 0 do
			if diggy.step(0, soft) == false then
				local	retv = diggy.change_dir()
				if retv == false then
					print("Error changing dir")
				end
			end
			dy = dy - 1
		end
	end

	function	move_z()
		local	dir, odir = 0, 0

		if dz > 0 then
			dir, odir = 1, 1
		elseif 0 > dz then
			dir, odir = 2, 0
			dz = dz * -1
		end
		if dir ~= 0 then
			while dz > 0 do
				if diggy.step(dir, soft) == false then
					local	retv = diggy.change_dir(odir)
					if retv == false then
						print("Error changing dir")
					end
				end
				dz = dz - 1
			end
		end
	end

	move_x()
	move_y()
	move_z()

	if diggy.pos.x ~= x or diggy.pos.y ~= y or diggy.pos.z ~= z then
		diggy.move(x, y, z, soft)
	end
end

function	diggy.base_move(waypoint)
	diggy.move(waypoint[1], waypoint[2], waypoint[3])
	diggy.face(waypoint[4])
end

function	diggy.deposit()
	local	ii = 1

	for i = (diggy.tool_slot * diggy.tool_stock) + 1, robot.inventorySize() do

		robot.select(i)
		while robot_ic.getStackInSlot(3, ii) do
			ii = ii + 1
		end
		robot_ic.dropIntoSlot(3, ii)
	end
end

function	diggy.free_move()
	while true do
		local	input = io.read()
		local	x, y, z = input:match("([^,]+),([^,]+),([^,]+)")
		print("("..x..","..y..","..z..")")
		diggy.move(x, y, z)
	end
end

function	diggy.get_energy()
	return computer.energy() * 100 / computer.maxEnergy()
end

function	diggy.recharge()
	local	max_energy = computer.maxEnergy()

	while computer.energy() < max_energy - 100 do
		os.sleep(.5)
	end
end

function	diggy.tool_type(slot, chest)
	local	stack = nil

	if chest == true then
		stack = robot_ic.getStackInSlot(3, slot)
	else
		stack = robot_ic.getStackInInternalSlot(slot)
	end
	if stack == nil or stack.label == nil then return "unknown" end

	if stack.label:find("Pickaxe") then return "pickaxe"
	elseif stack.label:find("Axe") then return "axe"
	elseif stack.label:find("Shovel") then return "shovel"
	end
	return "unknown"
end

function	diggy.tool_scan()
	local	available_tool = {}
	local	chest_size = robot_ic.getInventorySize(3)

	print("scanning "..chest_size.." slots")
	for i = 1, chest_size do
		local	tool_type = diggy.tool_type(i, true)
		local	already_available = false

		if tool_type ~= "unknown" then
			for i, v in ipairs(available_tool) do
				if v == tool_type then
					already_available = true
				end
			end

			if already_available == false then
				table.insert(available_tool, tool_type)
			end
		end
	end
	print("available tool in chest:")
	for i, v in ipairs(available_tool) do
		print("  - "..v)
	end
	return available_tool
end

function	diggy.deposit_tool()
	local	robot_size = robot.inventorySize()
	local	ii = 1

	for i = 1, robot_size do
		local	tool_type = diggy.tool_type(i)

		if tool_type ~= "unknown" then
			robot.select(i)
			while robot_ic.getStackInSlot(3, ii) do
				ii = ii + 1
			end
			robot_ic.dropIntoSlot(3, ii)
		end
	end
end

-- function	diggy.count_tool(tool, chest)
-- 	local	inventory_size = robot.inventorySize()
-- 	if chest then
-- 		inventory_size = robot_ic.getInventorySize(3)
-- 	end

-- 	local	n = 0
-- 	for i = 1, inventory_size do
-- 		if diggy.tool_type(i, chest) == tool then n = n + 1 end
-- 	end
-- end

function	diggy.tool_get(tool)
	local	chest_size = robot_ic.getInventorySize(3)

	for i = 1, chest_size do
		if diggy.tool_type(i, true) == tool then
			if robot_ic.suckFromSlot(3, i) then return true end
		end
	end
	return false
end

function	diggy.equip()
	local	chest_tool = diggy.tool_scan()
	diggy.tool_slot = #chest_tool
	local	ii = 1

	for i, v in ipairs(chest_tool) do
		local	i_stock = (i - 1) * diggy.tool_stock

		for j = i_stock + 1, i_stock + diggy.tool_stock do
			robot.select(j)
			local	t_tool = diggy.tool_type(j)
			if t_tool ~= v then
				while robot_ic.getStackInSlot(3, ii) do
					ii = ii + 1
				end
				robot_ic.dropIntoSlot(3, ii)
				if diggy.tool_get(v) == false then
					print("Error: getting tool")
				end
			end
		end
	end
end

function	diggy.refill()
	diggy.last_pos.x = diggy.pos.x
	diggy.last_pos.y = diggy.pos.y
	diggy.last_pos.z = diggy.pos.z

	if diggy.need_energy then
		diggy.base_move(base.charger)
		diggy.recharge()
		diggy.need_energy = false
	end
	if diggy.need_deposit then
		diggy.base_move(base.chest)
		diggy.deposit()
		diggy.need_deposit = false
	end
	if diggy.need_tool then
		diggy.base_move(base.tool)
		diggy.equip()
		diggy.need_tool = false
	end
	diggy.move(diggy.last_pos.x, diggy.last_pos.y, diggy.last_pos.z)
end

function	diggy.check_slot()
	local	robot_size = robot.inventorySize()
	local	free_slot = 0

	for i = (diggy.tool_slot * diggy.tool_stock) + 1, robot_size do
		local	s = robot_ic.getStackInInternalSlot(i)
		if s == nil then free_slot = free_slot + 1 end
	end
	return diggy.full_threshold >= free_slot
end

function	diggy.check_tool()
	for i = 0, diggy.tool_slot - 1 do
		local	tool = nil
		local	n_tool = 0
		for j = 1, diggy.tool_stock do
			local	k = (i * diggy.tool_stock) + j
			local	tmp_tool = diggy.tool_type(k)
			if tool == nil then
				if tmp_tool ~= "unknown" then
					tool = tmp_tool
					n_tool = n_tool + 1
				end
			else
				if tmp_tool == tool then
					n_tool = n_tool + 1
				end
			end
		end
		if n_tool ~= diggy.tool_stock then
			return true
		end
	end
	return false
end

function	diggy.print_state()
	function	ok(t) print("[ O ] "..t) end
	function	ko(t) print("[ X ] "..t) end

	if diggy.need_energy then ko("energy") else ok("energy") end
	if diggy.need_deposit then ko("deposit") else ok("deposit") end
	if diggy.need_tool then ko("tool") else ok("tool") end
end

function	diggy.check_state()
	diggy.need_energy = diggy.energy_threshold > diggy.get_energy()
	diggy.need_deposit = diggy.check_slot()
	diggy.need_tool = diggy.check_tool()

	diggy.print_state()
	diggy.refill()
end

function	diggy.init()
	if chat then chat.setName(DIGGY_NAME) end

	diggy.base_move(base.tool)
	diggy.deposit_tool()
	diggy.equip()
	diggy.check_state()
end

function	diggy.say(msg)
	if chat and QUIET ~= true then
		chat.say("["..diggy.pos.z.."] "..msg)
	end
end

-- MAIN

XC, YC, R = 0, 0, 5
DEPTH = 3

base = {
	["charger"] = {0, -8, 237, SOUTH},
	["chest"] = {4, -10, 237, SOUTH},
	["tool"] = {7, -10, 237, SOUTH},
}

diggy.init()

Xb, Yb, Zb = 0, R + 1, 237

while true do
	if diggy.pos.z == DEPTH then return end
	diggy.say(DIGGY_MSG)
	diggy.do_circle_perimeter(XC, YC, R)
	diggy.check_state()
	r2 = R - 1
	while r2 > 0 do
		local	c = circle.get(XC, YC, r2)
		for i, v in ipairs(c) do
			diggy.move(v[1], v[2], diggy.pos.z, false)
		end
		diggy.check_state()
		r2 = r2 - 1
	end
	diggy.move(XC, YC, diggy.pos.z, false)
	diggy.step(2, false)
end
