obs           = obslua
function new_vec2(x,y)
	local vec = obs.vec2()
	vec.x = x
	vec.y = y
	return vec
end

-- Properties
source_name   = nil
total_ms = 1000
screen_size = new_vec2(2560, 1440)
spam_size = 70

-- Internal state
playing = false
spam_items = {}
text_scene = nil
fps = 60
x_speed = screen_size.x/(total_ms/2)*(1000/fps)
hotkey_id     = obs.OBS_INVALID_HOTKEY_ID


-- Global script properties (magic function)
function script_properties()
	local props = obs.obs_properties_create()
	obs.obs_properties_add_int(props, "duration", "Duration (ms)", 1000, 10000, 250)
	obs.obs_properties_add_int(props, "size", "# of messages", 10, 200, 5)

	local p = obs.obs_properties_add_list(props, "source", "Text Source", obs.OBS_COMBO_TYPE_EDITABLE, obs.OBS_COMBO_FORMAT_STRING)
	local sources = obs.obs_enum_sources()
	if sources ~= nil then
		for _, source in ipairs(sources) do
			source_id = obs.obs_source_get_id(source)
			if source_id == "text_gdiplus" or source_id == "text_ft2_source" or source_id == "text_pango_source" then
				local name = obs.obs_source_get_name(source)
				obs.obs_property_list_add_string(p, name, name)
			end
		end
	end
	obs.source_list_release(sources)

	return props
end

-- A function named script_update will be called when settings are changed
function script_update(settings)
	source_name = obs.obs_data_get_string(settings, "source")
	total_ms = obs.obs_data_get_int(settings, "duration")
	spam_size = obs.obs_data_get_int(settings, "size")
end

-- A function named script_load will be called on startup
function script_load(settings)
	-- We need to aquire our hotkey_id on load.
	hotkey_id = obs.obs_hotkey_register_frontend("nnd.trigger", "NND Spam", play_event)
	local hotkey_save_array = obs.obs_data_get_array(settings, "nnd.trigger")
	obs.obs_hotkey_load(hotkey_id, hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
	obs.obs_add_tick_callback(render_call)
end

-- A function named script_save will be called when the script is saved
--
-- NOTE: This function is usually used for saving extra data (such as in this
-- case, a hotkey's save data).  Settings set via the properties are saved
-- automatically.
function script_save(settings)
	local hotkey_save_array = obs.obs_hotkey_save(hotkey_id)
	obs.obs_data_set_array(settings, "nnd.trigger", hotkey_save_array)
	obs.obs_data_array_release(hotkey_save_array)
end

-- A function named script_description returns the description shown to
-- the user
function script_description()
	return "Generates NicoNico style text spam based on your chosen text source\n\nLove,\nKurufu"
end

-- timer to clean everyhting up at the end hopefully.
function timer_callback()
	obs.obs_enter_graphics();
	for k,v in pairs(spam_items) do
		obs.obs_sceneitem_remove(v.s)
	end
	obs.obs_leave_graphics();
	spam_items = {}
	playing = false -- not concurrent safe
	obs.remove_current_callback()
end

-- Render tick
function render_call(seconds)
	if not playing then
		return
	end

	obs.obs_enter_graphics();
	for k,v in pairs(spam_items) do
		local pos = obs.vec2()
		obs.obs_sceneitem_get_pos(v.s, pos)
		pos.x = pos.x - x_speed*v.f
		obs.obs_sceneitem_set_pos(v.s, pos)
	end
	obs.obs_leave_graphics();
end

-- Helper for creating many clones
function create_spam_item(scene, text_source, text_sceneitem)
	sceneitem = obs.obs_scene_add(scene, text_source)
	if sceneitem == nil then
		obs.script_log(obs.LOG_WARNING, "NND failed to add source to scene")
	end
	obs.obs_sceneitem_set_visible(sceneitem, true)
	local size = new_vec2(math.random(screen_size.x)+screen_size.x, math.random(screen_size.y)) -- Copy
	local scale = obs.vec2()
	obs.obs_sceneitem_get_scale(text_sceneitem, scale) -- same size as source text
	obs.obs_sceneitem_set_scale(sceneitem, scale)
	obs.obs_sceneitem_set_pos(sceneitem, size)
	return sceneitem
end

-- Hotkey callback
function play_event()
	if playing then
		return
	else
		playing = true
		obs.timer_add(timer_callback, total_ms)
	end

	if source_name == nil then
		obs.script_log(obs.LOG_WARNING, "NND called with no source set")
		return
	end

	-- Do stuff here
	local curr_scene_s = obs.obs_frontend_get_current_scene()
	if curr_scene_s == nil then
		obs.script_log(obs.LOG_WARNING, "NND failed to find current scene!")
		return
	end
	text_scene = obs.obs_scene_from_source(curr_scene_s) -- takes no references
	local text_sceneitem = obs.obs_scene_find_source(text_scene, source_name) -- takes no references
	local text_source = obs.obs_get_source_by_name(source_name)

	local scale = obs.vec2()
	obs.obs_sceneitem_get_scale(text_sceneitem, scale) -- same size as source text
	local text_width = obs.obs_source_get_width(text_source) * scale.x -- width in pixel in current scene
	x_speed = (screen_size.x+text_width)/(total_ms/2)*(1000/fps) -- scale for long text to get it fully off screen

	obs.obs_enter_graphics();
	for i=1,spam_size do
		spam_items[i] =	{
			s=create_spam_item(text_scene, text_source, text_sceneitem),
			f=1+(math.random()/2) -- speed variance, no more than 50% faster
		}
	end
	obs.obs_leave_graphics();

	obs.obs_source_release(text_source)
	obs.obs_source_release(curr_scene_s)
end
