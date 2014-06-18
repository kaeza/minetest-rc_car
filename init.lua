
local unpack = unpack or table.unpack

local function mksinglepixelnodebox(res, box)
	local x, y, z, w, h, l = unpack(box)
	return {
		(x / res) - 0.5,
		(y / res) - 0.5,
		(z / res) - 0.5,
		((x + w) / res) - 0.5,
		((y + h) / res) - 0.5,
		((z + l) / res) - 0.5,
	}
end

local function mkpixelnodebox(res, boxes)
	local newboxes = { }
	for _, box in ipairs(boxes) do
		table.insert(newboxes, mksinglepixelnodebox(res, box))
	end
	return newboxes
end

local rc_pixelbox = mkpixelnodebox(16, {
	-- Body
	{ 4, 1, 0, 8, 3, 16 },
	{ 4, 4, 1, 8, 1, 14 },
	{ 4, 5, 4, 8, 1, 7 },
	{ 5, 6, 5, 6, 1, 5 },
	{ 3, 5, 0, 10, 1, 2 },
	-- Tires
	{ 3, 1, 10, 1, 2, 5 },
	{ 3, 1, 1, 1, 2, 5 },
	{ 3, 0, 2, 2, 1, 3 },
	{ 3, 0, 11, 2, 1, 3 },
	{ 12, 1, 10, 1, 2, 5 },
	{ 12, 1, 1, 1, 2, 5 },
	{ 11, 0, 2, 2, 1, 3 },
	{ 11, 0, 11, 2, 1, 3 },
})

local rc_collisionbox = mksinglepixelnodebox(16, { 0, 0, 0, 12, 7, 12 })

local creative_mode = minetest.setting_getbool("creative_mode")

minetest.register_node("rc_car:car", {
	description = "RC Car",
	drawtype = "nodebox",
	tiles = {
		"rc_car_car_tp.png",
		"rc_car_car_bt.png",
		"rc_car_car_rt.png",
		"rc_car_car_lt.png",
		"rc_car_car_ft.png",
		"rc_car_car_bk.png",
	},
	node_box = {
		type = "fixed",
		fixed = rc_pixelbox,
	},
	on_place = function(itemstack, placer, pointed_thing)
		local obj = minetest.add_entity(pointed_thing.above, "rc_car:car_entity")
		obj:setyaw(placer:get_look_yaw())
		local e = obj:get_luaentity()
		e.player = placer:get_player_name()
		if not creative_mode then
			itemstack:take_item()
			return itemstack
		end
	end,
})

minetest.register_entity("rc_car:car_entity", {
	visual = "wielditem",
	physical = true,
	textures = {"rc_car:car"},
	collisionbox = rc_collisionbox,
	automatic_face_movement_dir = 270,
	visual_size = { x=0.5, y=0.5, z=0.5 },
	stepheight = 0.55,
	on_activate = function(self)
		self.object:set_armor_groups({immortal=1})
		self.timer = 0
	end,
	on_punch = function(self, puncher)
		if puncher and puncher:is_player() then
			local inv = puncher:get_inventory()
			local stack = ItemStack("rc_car:car")
			if inv:room_for_item("main", stack) then
				if  (not creative_mode) or (not inv:contains_item("main", stack)) then
					inv:add_item("main", stack)
				end
				self.object:remove()
			end
		end
	end,
	on_rightclick = function(self, clicker)
		self.active = not self.active
		if not self.active then
			self.object:setvelocity({x=0, y=0, z=0})
		end
	end,
	on_step = function(self, dtime)
		if not self.player then
			self.object:remove()
			return
		end
		self.timer = self.timer + dtime
		if self.timer < 1 then return end
		if not self.active then return end
		self.timer = 0
		local pl = minetest.get_player_by_name(self.player)
		if not pl then
			self.object:remove()
			return
		end
		if self.target_pos then
			local mypos = self.object:getpos()
			if vector.distance(mypos, self.target_pos) < 0.5 then return end
			local vel = vector.normalize({
				x = self.target_pos.x - mypos.x,
				y = 0,
				z = self.target_pos.z - mypos.z,
			})
			vel.x = vel.x * 3
			vel.y = vel.y * 3
			vel.z = vel.z * 3
			self.object:setvelocity(vel)
			self.object:setacceleration({x=0, y=-4, z=0})
		end
	end,
})

minetest.register_craftitem("rc_car:remote", {
	description = "RC Car",
	drawtype = "nodebox",
	inventory_image = "rc_car_remote.png",
	on_use = function(itemstack, user, pointed_thing)
		if pointed_thing.type == "node" then
			local plname = user:get_player_name()
			for _, obj in ipairs(minetest.get_objects_inside_radius(user:getpos(), 20)) do
				local e = obj:get_luaentity()
				if e and (e.name == "rc_car:car_entity") and (e.player == plname) then
					local p = pointed_thing.above
					e.target_pos = p
				end
			end
		end
	end,
})
