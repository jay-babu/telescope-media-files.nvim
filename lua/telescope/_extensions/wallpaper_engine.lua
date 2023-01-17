local has_telescope, _ = pcall(require, "telescope")
local Job = require("plenary.job")

if not has_telescope then
	error("This plugin requires telescope.nvim (https://github.com/nvim-telescope/telescope.nvim)")
end

local utils = require("telescope.utils")
local defaulter = utils.make_default_callable
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local previewers = require("telescope.previewers")
local conf = require("telescope.config").values

local M = {}

local filetypes = {}
local find_cmd = ""
local image_stretch = 250

M.base_directory = ""
M.media_preview = defaulter(function(opts)
	return previewers.new_termopen_previewer({
		get_command = opts.get_command or function(entry)
			local tmp_table = vim.split(entry.value, "\t")
			local preview = opts.get_preview_window()
			opts.cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.loop.cwd()
			if vim.tbl_isempty(tmp_table) then
				return { "echo", "" }
			end
			return {
				M.base_directory .. "/scripts/vimg",
				tmp_table[1],
				preview.col,
				preview.line + 1,
				preview.width,
				preview.height,
				image_stretch,
			}
		end,
	})
end, {})

function M.wallpaper_engine(opts)
	local find_commands = {
		rg = {
			"bash",
			"/home/archy/code/telescope-wallpaper-engine.nvim/scripts/refresh",
		},
	}

	if not vim.fn.executable(find_cmd) then
		error("You don't have " .. find_cmd .. "! Install it first or use other finder.")
		return
	end

	if not find_commands[find_cmd] then
		error(find_cmd .. " is not supported!")
		return
	end

	local sourced_file = require("plenary.debug_utils").sourced_filepath()
	M.base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h:h")
	opts = opts or {}
	opts.attach_mappings = function(prompt_bufnr, map)
		actions.select_default:replace(function()
			local entry = action_state.get_selected_entry()
			Job:new({
				command = [[/mnt/c/Program Files (x86)/Steam/steamapps/common/wallpaper_engine/wallpaper32.exe]],
				args = { "-control", "openWallpaper", "-file", entry.projectPath },
			}):start()
			actions.close(prompt_bufnr)
		end)
		return true
	end
	opts.entry_maker = function(entry)
		local jqEntry = vim.json.decode(entry)
		if jqEntry == nil then
			return
		end

		return {
			value = vim.fn.resolve(jqEntry.path .. jqEntry.fileName),
			display = jqEntry.title,
			ordinal = jqEntry.title,
			projectPath = [[C:\Program Files (x86)\Steam\steamapps\workshop\content\431960\]]
					.. jqEntry.folderId
					.. [[\project.json]],
		}
	end

	local popup_opts = {}
	opts.get_preview_window = function()
		return popup_opts.preview
	end
	local picker = pickers.new(opts, {
		prompt_title = "Wallpaper Engine Picker",
		finder = finders.new_oneshot_job(find_commands[find_cmd], opts),
		previewer = M.media_preview.new(opts),
		sorter = conf.file_sorter(opts),
	})

	local line_count = vim.o.lines - vim.o.cmdheight
	if vim.o.laststatus ~= 0 then
		line_count = line_count - 1
	end
	popup_opts = picker:get_window_options(vim.o.columns, line_count)
	picker:find()
end

return require("telescope").register_extension({
	setup = function(ext_config)
		filetypes = ext_config.filetypes or { "png", "jpg", "gif", "mp4", "webm", "pdf" }
		-- find_cmd = ext_config.find_cmd or "rg"
		find_cmd = "rg"
		image_stretch = ext_config.image_stretch or 250
	end,
	exports = {
		wallpaper_engine = M.wallpaper_engine,
	},
})
