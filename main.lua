local show_hitboxes = false
local explosion_life = 45
local bullet_life = 45

local overlays = {}
local ids = {}

gui.add_to_menu_bar(function()
	show_hitboxes, pressed = ImGui.Checkbox("Show Hitboxes", show_hitboxes)
	if pressed and not show_hitboxes then
		ids = {}
		overlays = {}
	end
	explosion_life = ImGui.DragFloat("Explosion Lifetime (frames)", explosion_life, 1, 0, 600)
	bullet_life = ImGui.DragFloat("Bullet Lifetime (frames)", bullet_life, 1, 0, 600)
end)

local pre_hooks = {}
local post_hooks = {}

gm.pre_code_execute(function(self, other, code, result, flags)
    if pre_hooks[code.name] then
        pre_hooks[code.name](self)
    end
end)
gm.post_code_execute(function(self, other, code, result, flags)
    if post_hooks[code.name] then
        post_hooks[code.name](self)
    end
end)

local hitboxers = {
	[gm.constants.pInteractable] = true,
	[gm.constants.pBlock] = true,
	[gm.constants.oRope] = true,
	[gm.constants.pActorCollisionBase] = true,
	[gm.constants.pPickup] = true,
	[gm.constants.oArtiChakram] = true,
	[gm.constants.oArtiNanobomb] = true,
	[gm.constants.pProjectileBase] = true,
	[gm.constants.pProjectileTracer] = true,
	[gm.constants.oBrambleBullet] = true,
	[gm.constants.oMushDust] = true,
	[gm.constants.oCustomObject] = true,
	[gm.constants.oEfArtiStar] = true,
}
local special_cases = {
	[gm.constants.oTurtle] = gm.constants.sTurtleHeadMask,
}

local team_colours = {
	[1.0] = gm.make_colour_rgb(0, 255, 0),
	[2.0] = gm.make_colour_rgb(255, 0, 0),
}

local function team_colour(inst)
	local col
	local team = inst.team
	if not team then
		local parent = inst.parent
		if parent then
			team = parent.team
		end
	end
	if team then
		col = team_colours[team]
	end
	if not col then
		col = 16777215
	end
	return col
end

local function draw_hitbox(inst)
	local col = team_colour(inst)
	local spec = special_cases[inst.object_index]
	if spec then
		gm.draw_sprite_ext(spec, 0, inst.x, inst.y, inst.image_xscale, inst.image_yscale, 0, col, 0.15)
		return
	end

	gm.draw_set_colour(col)
	gm.draw_set_alpha(0.15)
	gm.draw_rectangle(inst.bbox_left+1, inst.bbox_top+1, inst.bbox_right-1, inst.bbox_bottom-1, false)
	gm.draw_set_alpha(1.0)
	gm.draw_rectangle(inst.bbox_left+1, inst.bbox_top+1, inst.bbox_right-1, inst.bbox_bottom-1, true)
end

-- be prepared to see the most horrid unreadable dogshit you've ever seen
post_hooks["gml_Object_oInit_Draw_73"] = function(self)
	if not show_hitboxes then return end

	local camera = gm.view_get_camera(0)
	local vx, vy, vw, vh = gm.camera_get_view_x(camera), gm.camera_get_view_y(camera), gm.camera_get_view_width(camera), gm.camera_get_view_height(camera)
	local left, right, top, bottom = vx, vx + vw, vy, vy + vh

	local inst
	local obj

	for i=1, #gm.CInstance.instances_active do
		inst = gm.CInstance.instances_active[i]
		obj = inst.object_index

		for i=1, 10 do
			if not hitboxers[obj] then
				obj = gm.object_get_parent_w(obj)
				if obj == -100 then
					break
				end
			end
		end
		if hitboxers[obj] and
			inst.bbox_right > left and
			inst.bbox_left < right and
			inst.bbox_bottom > top and
			inst.bbox_top < bottom then
			draw_hitbox(inst)
		end
	end

	for i, boom in ipairs(overlays) do
		if boom.rotated then
			gm.draw_sprite_ext(gm.constants.sBite1Mask, 0, boom.x, boom.y, boom.xscale, boom.yscale, boom.angle, 16777215, 0.25)
		else
			local col = team_colour(boom)
			gm.draw_set_colour(col)
			if boom.is_line then
				gm.draw_set_alpha(0.75)
				gm.draw_line(boom.x1, boom.y1, boom.x2, boom.y2)
			else
				gm.draw_set_alpha(0.15)
				gm.draw_rectangle(boom.x1, boom.y1, boom.x2, boom.y2, false)
				gm.draw_set_alpha(0.5)
				gm.draw_rectangle(boom.x1, boom.y1, boom.x2, boom.y2, true)
			end
		end
	end
	gm.draw_set_alpha(1.0)

	for i, boom in ipairs(overlays) do
		boom.lifetime = boom.lifetime - 1
		if boom.lifetime < 0 then
			table.remove(overlays, i)
			ids[boom.id] = nil
		end
	end
end

local callback_names = gm.variable_global_get("callback_names")
local on_attack_end = 0
for i = 1, #callback_names do
    local callback_name = callback_names[i]
    if callback_name:match("onAttackHandleEnd") then
        on_attack_end = i - 1
    end
end

gm.pre_script_hook(gm.constants.callback_execute, function(self, other, result, args)
	if not show_hitboxes then return end
	if args[1].value == on_attack_end then
		local attack_info = args[2].value
		if attack_info.attack_type == 0.0 then
			local line = {
				is_line = true,
				id = -1,
				x1 = attack_info.x,
				y1 = attack_info.y,
				--x2 = self.attack_info.x + gm.lengthdir_x(dist, self.attack_info.direction),
				--y2 = self.attack_info.y + gm.lengthdir_y(dist, self.attack_info.direction),
				x2 = gm.variable_global_get("collision_x"),
				y2 = gm.variable_global_get("collision_y"),
				team = attack_info.team,
				lifetime = bullet_life,
			}

			table.insert(overlays, line)
		end
	end
end)

pre_hooks["gml_Object_oExplosionAttack_Step_1"] = function(self)
	if not show_hitboxes then return end
	if ids[self.id] then return end
	ids[self.id] = true

	if self.image_angle ~= 0 then
		local attack = {
			rotated = true,
			id = self.id,
			x = self.x,
			y = self.y,
			angle = self.image_angle,
			xscale = self.image_xscale,
			yscale = self.image_yscale,
			team = self.attack_info.team,
			lifetime = explosion_life,
		}

		table.insert(overlays, attack)
		return
	end

	local attack = {
		rotated = false,
		id = self.id,
		x1 = self.bbox_left,
		x2 = self.bbox_right,
		y1 = self.bbox_top,
		y2 = self.bbox_bottom,
		team = self.attack_info.team,
		lifetime = explosion_life,
	}

	table.insert(overlays, attack)
end

-- handle big provi laser
gm.pre_script_hook(gm.constants.collision_rectangle_list, function(self, other, result, args)
	if not show_hitboxes then return end
	if self.object_index == gm.constants.oEfBoss4SliceDoT then
		local attack = {
			rotated = false,
			id = self.id,
			x1 = args[1].value,
			y1 = args[2].value,
			x2 = args[3].value,
			y2 = args[4].value,
			team = self.team,
			lifetime = explosion_life,
		}
		table.insert(explosion_list, attack)
	end
end)
