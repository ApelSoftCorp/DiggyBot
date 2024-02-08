--- [[ INCLUDES ]] ---

--- Importing necessary libraries.
local serial = require("serialization")
local component = require("component")
local computer = require("computer")
local robot = require("robot")
local robot_ic = component.inventory_controller
local chat = component.chat

--- [[ CUSTOM ]] ---

local circle = require("circle")

---@meta
-- Constants defining directions
NORTH = 0
EAST = 1
SOUTH = 2
WEST = 3
RIGHT = 4
LEFT = 5

--- [[ CONFIG ]] ---

-- Configuration variables
DIGGY_NAME = "DiggyBot"
DIGGY_MSG = "DIGGY DIGGY HOLE, DIGGY DIGGY HOLE"
QUIET = false

-- Set chat name if chat component is available
if chat then chat.setName(DIGGY_NAME) end

-- Diggy's configuration
---@class diggy
local	diggy = {
	-- Current position
	["pos"] = {
		["x"] = -241,
		["y"] = 4,
		["z"] = -1033
	},
	-- Last known position
	["last_pos"] = {
		["x"] = 0,
		["y"] = 0,
		["z"] = 0
	},
	-- Inventory size
	["inv_size"] = robot.inventorySize(),
	-- Current facing direction
	["facing"] = EAST,
	-- Stock of tools
	["tool_stock"] = 2,
	-- Tool definitions
	["tool"] = {
		["pickaxe"] = {
			["pattern"] = {
				"Pickaxe",
				"pickaxe"
			},
			["slot"] = 0
		},
		["shovel"] = {
			["pattern"] = {
				"Shovel",
				"shovel"
			},
			["slot"] = 1
		},
		["axe"] = {
			["pattern"] = {
				"Axe"
			},
			["slot"] = 2
		},
		["replace_block"] = {
			["pattern"] = {
				"Wool"
			},
			["slot"] = 3
		},
	},
	-- Threshold for inventory fullness
	["full_threshold"] = 2,
	-- Threshold for energy level
	["energy_threshold"] = 15,
	-- Flags indicating need for energy, deposit, and tool
	["need_energy"] = false,
	["need_deposit"] = false,
	["need_tool"] = false
}

-- Order of tools to be checked
tool_order = {
	"pickaxe",
	"shovel",
	"axe",
	"replace_block"
}

-- Base waypoints
base = {
	["charger"] = {-263, -1033, 4, WEST},
	["deposit"] = {-263, -1028, 4, WEST},
	["tool"] = {-263, -1021, 4, WEST},
}

--- [[ UTILS ]] ---

--- Formats position coordinates into a string.
---@param x number # The x-coordinate.
---@param z number # The z-coordinate.
---@param y? number # The optional y-coordinate.
---@return string # Formatted position string.
function	fpos(x, z, y)
	if y then return "("..x..","..z..","..y..")"
	end
	return "("..x..","..z..")"
end

--- Generates a list of random numbers.
---@param len number # The length of the list.
---@return table # List of random numbers.
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

--- Saves circle data to files.
---@param c table # The table containing circle data.
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

--- [[ MOVE ]] ---

--- Determines the new facing direction after a rotation.
---@param dir number # The direction of rotation (RIGHT or LEFT).
---@return number # The new facing direction.
function	diggy.get_face(dir)
	if dir == RIGHT then
		if diggy.facing == NORTH then return EAST
		elseif diggy.facing == SOUTH then return WEST
		elseif diggy.facing == EAST then return SOUTH
		elseif diggy.facing == WEST then return NORTH
		end
	elseif dir == LEFT then
		if diggy.facing == NORTH then return WEST
		elseif diggy.facing == SOUTH then return EAST
		elseif diggy.facing == EAST then return NORTH
		elseif diggy.facing == WEST then return SOUTH
		end
	end
end

--- Rotates the robot to face a specified direction.
---@param dir number # The target direction to face.
function	diggy.face(dir)
	if dir == diggy.facing then
		return
	elseif dir == NORTH then
		if diggy.facing == EAST then robot.turnLeft()
		elseif diggy.facing == SOUTH then robot.turnAround()
		elseif diggy.facing == WEST then robot.turnRight()
		end
	elseif dir == SOUTH then
		if diggy.facing == WEST then robot.turnLeft()
		elseif diggy.facing == NORTH then robot.turnAround()
		elseif diggy.facing == EAST then robot.turnRight()
		end
	elseif dir == EAST then
		if diggy.facing == SOUTH then robot.turnLeft()
		elseif diggy.facing == WEST then robot.turnAround()
		elseif diggy.facing == NORTH then robot.turnRight()
		end
	elseif dir == WEST then
		if diggy.facing == NORTH then robot.turnLeft()
		elseif diggy.facing == EAST then robot.turnAround()
		elseif diggy.facing == SOUTH then robot.turnRight()
		end
	elseif dir == RIGHT then
		diggy.face(diggy.get_face(RIGHT))
		return
	elseif dir == LEFT then
		diggy.face(diggy.get_face(LEFT))
		return
	end
	diggy.facing = dir
end

--- Changes the direction of movement based on the parameter 'd'.
---@param d number # The direction of movement (0 for forward, 1 for up, 2 for right, 3 for left).
---@return boolean # True if the movement is successful, false otherwise.
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

--- Changes the direction of movement to avoid obstacles.
---@param opposed_dir number # The direction opposed to the current movement direction.
---@return boolean # `true` if the direction change is successful, `false` otherwise.
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

--- Moves the robot one step in the specified direction.
---@param dir number # The direction to move (any for forward, 1 for up, 2 for down).
---@param soft boolean # Whether to treat obstacles as soft (allowing the robot to dig through) or hard (preventing movement).
---@return boolean # True if the movement is successful, false otherwise.
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
		diggy.pos.y = diggy.pos.y + 1
	elseif dir == 2 then
		diggy.pos.y = diggy.pos.y - 1
	else
		if diggy.facing == EAST then
			diggy.pos.x = diggy.pos.x + 1
		elseif diggy.facing == WEST then
			diggy.pos.x = diggy.pos.x - 1
		elseif diggy.facing == SOUTH then
			diggy.pos.z = diggy.pos.z + 1
		elseif diggy.facing == NORTH then
			diggy.pos.z = diggy.pos.z - 1
		end
	end
	return true
end

--- Moves the robot to a specified position.
---@param x number # he target x-coordinate.
---@param z number # The target z-coordinate.
---@param y? number # The optional target y-coordinate.
---@param soft boolean # Whether to treat obstacles as soft (allowing the robot to dig through) or hard (preventing movement).
function	diggy.move(x, z, y, soft)
	local	y = y or diggy.pos.y
	local	dx = x - diggy.pos.x
	local	dy = y - diggy.pos.y
	local	dz = z - diggy.pos.z

	--- Moves the robot along the x-axis.
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

	--- Moves the robot along the z-axis.
	function	move_z()
		if dz > 0 then
			diggy.face(SOUTH)
		elseif 0 > dz then
			diggy.face(NORTH)
			dz = dz * -1
		end

		while dz > 0 do
			if diggy.step(0, soft) == false then
				local	retv = diggy.change_dir()
				if retv == false then
					print("Error changing dir")
				end
			end
			dz = dz - 1
		end
	end

	--- Moves the robot along the y-axis.
	function	move_y()
		local	dir, odir = 0, 0

		if dy > 0 then
			dir, odir = 1, 1
		elseif 0 > dy then
			dir, odir = 2, 0
			dy = dy * -1
		end
		if dir ~= 0 then
			while dy > 0 do
				if diggy.step(dir, soft) == false then
					local	retv = diggy.change_dir(odir)
					if retv == false then
						print("Error changing dir")
					end
				end
				dy = dy - 1
			end
		end
	end

	move_x()
	move_z()
	move_y()

	if diggy.pos.x ~= x or diggy.pos.y ~= y or diggy.pos.z ~= z then
		diggy.move(x, z, y, soft)
	end
end

--- Allows manual movement input by reading coordinates from the console.
function	diggy.free_move()
	while true do
		local	input = io.read()
		local	x, y, z = input:match("([^,]+),([^,]+),([^,]+)")
		print("("..x..","..y..","..z..")")
		diggy.move(x, y, z)
	end
end

--- [[ INTERACT ]] ---

--- Determines the inventory slot of the next tool.
---@return number # The inventory slot of the next tool.
function	diggy.get_block_slot()
	local	slot = #tool_order * diggy.tool_stock
	if tool_order[#tool_order]:find("block") then
		return slot - diggy.tool_stock
	end
	return slot
end

--- Swings the robot's equipped tool in a specified direction.
---@param side number # The direction to swing the tool (0 for forward, 1 for up, 2 for down).
---@return boolean # True if the swing is successful, false otherwise.
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
	for i = 1, diggy.get_block_slot(), 2 do
		robot.select(i)
		robot_ic.equip()
		if swing() then
			return true
		end
	end
	return false
end

--- Selects an item from the inventory with a count greater than 2.
---@return boolean # True if a suitable item is found and selected, false otherwise.
function	diggy.select_item()
	for i = diggy.get_block_slot() + 1, 15 do
		if robot.count(i) > 2 then
			robot.select(i)
			return true
		end
	end
	return false
end

--- Places a block in the specified direction using the robot's current item.
---@param side number # The direction to place the block (NORTH, EAST, SOUTH, WEST).
function	diggy.place(side)
	diggy.select_item()
	diggy.face(side)
	robot.place()
end

--- Outputs a message in the chat if available and not in quiet mode.
---@param msg string # The message to output.
function	diggy.say(msg)
	if chat and QUIET ~= true then
		chat.say("["..diggy.pos.y.."] "..msg)
	end
end

--- [[ DIG ]] ---

	--- [[ CIRCLE / CYLINDER ]] ---

--- Digs the perimeter of a circle defined by its center coordinates (xc, zc) and radius (r).
---@param xc number # The x-coordinate of the circles center.
---@param zc number # The z-coordinate of the circles center.
---@param r number # The radius of the circle.
function	diggy.do_circle_perimeter(xc, zc, r)
	local	c = circle.get(xc, zc, r)

	for i, v in ipairs(c) do
		diggy.move(v[1], v[2], diggy.pos.y, false)
		if circle.is_in(v[1] + 1, v[2], xc, zc, r) == false then
			diggy.place(EAST)
		end
		if circle.is_in(v[1] - 1, v[2], xc, zc, r) == false then
			diggy.place(WEST)
		end
		if circle.is_in(v[1], v[2] + 1, xc, zc, r) == false then
			diggy.place(SOUTH)
		end
		if circle.is_in(v[1], v[2] - 1, xc, zc, r) == false then
			diggy.place(NORTH)
		end
	en
end

--- Digs a cylindrical area around a center point with optional height.
---@param xc number # The x-coordinate of the cylinders center.
---@param zc number # The z-coordinate of the cylinders center.
---@param yc? number # The optional y-coordinate of the cylinders base.
---@param r number # The radius of the cylinder.
---@param d number # The height of the cylinder.
function	diggy.dig_cylinder(xc, zc, yc, r, d)
	local	yc = yc or diggy.pos.y

	diggy.move(xc, zc, yc, false)
	while true do
		diggy.say(DIGGY_MSG)
		diggy.do_circle_perimeter(xc, zc, r)
		diggy.check_state()
		r2 = r - 1
		while r2 > 0 do
			local	c = circle.get(xc, zc, r2)
			for i, v in ipairs(c) do
				diggy.move(v[1], v[2], diggy.pos.y, false)
			end
			diggy.check_state()
			r2 = r2 - 1
		end
		if diggy.pos.y == DEPTH then return end
		diggy.move(xc, zc, diggy.pos.y, false)
		diggy.step(2, false)
	end
end

--- [[ CHECK ]] ---

--- Retrieves the current energy level as a percentage.
---@return number # The current energy level.
function	get_energy()
	return computer.energy() * 100 / computer.maxEnergy()
end

--- Checks if the inventory needs to be deposited.
---@return boolean # True if the inventory needs to be deposited, false otherwise.
function	diggy.check_deposit()
	local	robot_size = robot.inventorySize()
	local	free_slot = 0

	for i = (#tool_order * diggy.tool_stock) + 1, robot_size do
		local	s = robot_ic.getStackInInternalSlot(i)
		if s == nil then free_slot = free_slot + 1 end
	end
	return diggy.full_threshold >= free_slot
end

--- Checks if any tools need to be replenished.
---@return boolean # True if any tools need to be replenished, false otherwise.
function	diggy.check_tool()
	for i = 0, #tool_order - 1 do
		local	tool = nil
		local	n_tool = 0
		for j = 1, diggy.tool_stock do
			local	k = (i * diggy.tool_stock) + j
			local	tmp_tool = diggy.tool_type(k)
			if tool == nil then
				if tmp_tool ~= "unknown" and tmp_tool ~= "void" then
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

--- [[ BASEMENT ]] ---

	--- [[ TOOL ]] ---

--- Determines the type of tool in a specified inventory slot.
---@param slot number # The inventory slot to check.
---@param chest boolean # Whether the inventory is a chest.
---@return string # The type of tool in the slot ("pickaxe", "shovel", "axe", "replace_block", "void", or "unknown").
function	diggy.tool_type(slot, chest)
	local	stack = nil

	if chest == true then
		stack = robot_ic.getStackInSlot(3, slot)
	else
		stack = robot_ic.getStackInInternalSlot(slot)
	end
	if stack == nil then return "void" end

	for tool_name, t in pairs(diggy.tool) do
		for i, pattern in ipairs(t.pattern) do
			if stack.label:find(pattern) or stack.name:find(pattern) then
				return tool_name
			end
		end
	end
	return "unknown"
end

--- Unequips the robot's current tool.
---@return boolean # True if the tool is successfully unequipped, false otherwise.
function	diggy.tool_unequip()
	local	ii = 1

	for i = 1, diggy.inv_size do
		local	tool_type = diggy.tool_type(i)
		if tool_type == "void" then
			robot.select(i)
			robot_ic.equip()
			print("unequiped")
			return true
		end
	end
	return false
end

--- Checks if a tool is currently equipped.
---@return boolean # True if a tool is currently equipped, false otherwise.
function	diggy.tool_is_equiped()
	local	retv, err = robot.durability()
	if retv == nil and err == "no tool equipped" then
		return false
	end
	return true
end

--- Sorts tools in the inventory to ensure they are grouped together by type.
---@param id string # The type of tool to sort ("pickaxe", "shovel", "axe", or "replace_block").
---@return number # The number of missing tool slots filled during sorting.
function	diggy.tool_sort(id)
	local	slot_id = (diggy.tool[id].slot * diggy.tool_stock) + 1
	local	n = 0

	for i = 1, diggy.inv_size do
		local	t_tool = diggy.tool_type(i)
		if t_tool == id then
			if i ~= slot_id then
				robot.select(i)
				robot.transferTo(slot_id)
			end
			slot_id = slot_id + 1
			n = n + 1
			if n == diggy.tool_stock then
				return 0
			end
		end
	end
	return diggy.tool_stock - n
end

--- Retrieves a tool from a chest inventory.
---@param tool string # The type of tool to retrieve.
---@return boolean # True if the tool is successfully retrieved, false otherwise.
function	diggy.tool_get(tool)
	local	chest_size = robot_ic.getInventorySize(3)

	for i = 1, chest_size do
		if diggy.tool_type(i, true) == tool then
			if robot_ic.suckFromSlot(3, i) then return true end
		end
	end
	return false
end

--- Refills the inventory with the specified type of tool.
---@param id string # The type of tool to refill ("pickaxe", "shovel", "axe", or "replace_block").
---@param missing number # The number of missing tool slots.
function	diggy.tool_fill(id, missing)
	local	slot_id = (diggy.tool[id].slot * diggy.tool_stock) + 1

	for i = slot_id, slot_id + diggy.tool_stock - 1 do
		local	t_tool = diggy.tool_type(i)
		if t_tool == "void" then
			robot.select(i)
			diggy.tool_get(id)
		end
	end
end

--- Automatically refills all tools in the inventory.
function	diggy.tool_refill()
	if diggy.tool_is_equiped() then diggy.tool_unequip() end

	for i, v in ipairs(tool_order) do
		local	missing = diggy.tool_sort(v)
		if missing ~= 0 then
			diggy.tool_fill(v, missing)
		end
	end
end

	--- [[ OTHER ]] ---

--- Moves the robot to a specified waypoint in the base.
---@param waypoint table # The waypoint table containing coordinates and facing direction.
function	diggy.base_move(waypoint)
	diggy.move(waypoint[1], waypoint[2], waypoint[3])
	diggy.face(waypoint[4])
end

--- Deposits items from the robot's inventory into a chest.
function	diggy.deposit()
	local	ii = 1

	for i = diggy.get_block_slot() + 1, diggy.inv_size do

		robot.select(i)
		while robot_ic.getStackInSlot(3, ii) do
			ii = ii + 1
		end
		robot_ic.dropIntoSlot(3, ii)
	end
end

--- Recharges the robot's energy until it reaches a specified threshold.
function	diggy.recharge()
	local	max_energy = computer.maxEnergy()

	while computer.energy() < max_energy - 100 do
		os.sleep(.5)
	end
end

--- Refills energy, deposits items, and replenishes tools based on current needs.
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
		diggy.base_move(base.deposit)
		diggy.deposit()
		diggy.need_deposit = false
	end
	if diggy.need_tool then
		diggy.base_move(base.tool)
		diggy.tool_refill()
		diggy.need_tool = false
	end
	diggy.move(diggy.last_pos.x, diggy.last_pos.z, diggy.last_pos.y)
end

--- Prints the current state of energy, deposit, and tool needs.
function	diggy.print_state()
	function	ok(t) print("[ O ] "..t) end
	function	ko(t) print("[ X ] "..t) end

	if diggy.need_energy then ko("energy") else ok("energy") end
	if diggy.need_deposit then ko("deposit") else ok("deposit") end
	if diggy.need_tool then ko("tool") else ok("tool") end
end

--- Checks the current state of energy, deposit, and tool needs and takes appropriate actions.
function	diggy.check_state()
	diggy.need_energy = diggy.energy_threshold > get_energy()
	diggy.need_deposit = diggy.check_deposit()
	diggy.need_tool = diggy.check_tool()

	diggy.print_state()
	diggy.refill()
end

--- [[ MAIN ]] ---

-- Checks the initial state and starts the digging operation.
diggy.check_state()
diggy.dig_cylinder(-228, -1033, 4, 10, 1)
