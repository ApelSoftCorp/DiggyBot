# OpenComputer Lib

## How To

### Setup update.template.lua

This repository is a template from this
[repository](https://github.com/Pixailz/OpenComputer), and it includes an
`update.template.lua` that needs to be configured to easily transfer files
between the host PC and the OC PC.

Please refer to it for more information.

### Use DiggyBot

#### 1. Starting Position and Facing

You have to set up DiggyBot with its current coordinates or a relative one, and
specify which cardinal point it faces.

The position can be set at `diggy.pos` and the facing direction at `diggy.facing`.

> [!TIP]
> With this, you can use the `diggy.move` function to make it move to a position.

#### 2. Tools Needed

You can set up DiggyBot to retrieve some tools from a chest, which are necessary
for breaking blocks and placing them, when block are missing in the perimeter of
a digging plan.

The structure to specify these tools is in the `diggy.tool` part.

Each slot is unique in order to avoid undesirable effects and should start at 0.

In addition to this specification, a `tool_order` list is needed to specify the
number of tools needed and other optimizations.

Finally, you can specify a `diggy.tool_stock` indicating how many tools you want
to have (recommended value: 2-4).

```lua
local	diggy = {
	...
	["tool_stock"] = 2,
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
	...
}

tool_order = {
	"pickaxe",
	"shovel",
	"axe",
	"replace_block"
}
```

Every tool name that contain **block** in it will be tried to be placed when
`diggy.place(face)` is called

#### 3. Basement

Thirdly you have to setup some coordinate to make a basement for DiggyBot
here's some point you can setup:

```lua
base = {
	["charger"] = {-263, -1033, 4, WEST},
	["deposit"] = {-263, -1028, 4, WEST},
	["tool"] = {-263, -1021, 4, WEST},
}
```

From first to last; Xpos, Zpos, Ypos, Side to face (for exemple chest need to be
faced in order to be interacted)

## ToDo

1. try to fix dumb soft movement. maybe stop direction when changing_dir()
1. implement persistence (save position)
1. diggy.select_item(), make a `is_tool` function
1. after refac, make the whole thing a service
   1. diggy start circle x, y, z, r, depth
   2. diggy freemove
   3. diggy sleep
   4. diggy status
