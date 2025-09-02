import('core.project.depend')
import("utils.progress", {
	alias = "progress_utils"
})

local function _get_cfg(target)
	local cfg = {}

	cfg.multiple = target:values('easy.qmldir.multiple_modules') or false
	cfg.to_qrc = target:values('easy.qmldir.add_to_qrc') or false

	cfg.module = target:values('easy.qmldir.module') or target:values('qt.qmlplugin.import_name')
	cfg.module_dir = path.join(table.unpack(cfg.module:split('.', {
		plain = true
	})))

	cfg.version = target:values('easy.qmldir.version')
	if not cfg.version then
		local major = target:values('qt.qmlplugin.majorversion') or 1
		local minor = target:values('qt.qmlplugin.minorversion') or 0
		cfg.version = string.format('%d.%d', major, minor)
	end

	cfg.optional_plugin = target:values('easy.qmldir.optional_plugin') or false
	cfg.plugin = target:values('easy.qmldir.plugin') or target:name()
	cfg.plugin_path = target:values('easy.qmldir.plugin_path')
	cfg.classname = target:values('easy.qmldir.classname')
	cfg.typeinfo = target:values('easy.qmldir.typeinfo') or 'plugins.qmltypes'
	cfg.depends = target:values('easy.qmldir.depends') or {}
	cfg.imports = target:values('easy.qmldir.imports') or {}
	cfg.designersupported = target:values('easy.qmldir.designersupported') or false
	cfg.prefer = target:values('easy.qmldir.prefer')

	return cfg
end

-- Helper to write lists of strings with a type prefix
local function _add_list(qmldir, kind, list)
	if list and #list > 0 then
		for _, item in ipairs(list) do
			table.insert(qmldir, {kind, item})
		end
		table.insert(qmldir, {})
	end
end

local function _is_singleton(f)
	if not os.exists(f) then
		return false
	end

	local contents = io.readfile(f)
	-- find "pragma Singleton" before first '{'
	return contents:match('^%s*pragma%s+Singleton%s+[^{]+{')
end

local function _get_module_names(inputs, basedir)
	local modules = {}
	for _, file in ipairs(inputs) do
		local mod = path.directory(path.relative(file, basedir))
		table.insert(modules, mod)
	end
	table.sort(modules)
	return table.unique(modules)
end

local function _group_by_module(inputs, basedir)
	local groups = {}
	for _, file in ipairs(inputs) do
		local mod = path.directory(path.relative(file, basedir))
		groups[mod] = groups[mod] or {}
		table.insert(groups[mod], file)
	end
	for _, files in pairs(groups) do
		table.sort(files)
	end
	return groups
end

local function _get_base_dir(target)
	local basedir = path.relative(path.join(target:scriptdir()), os.projectdir())
	local cfg_basedir = target:values('easy.qmldir.base_dir')
	if cfg_basedir then
		basedir = path.join(basedir, cfg_basedir)
	end
	return basedir
end

function on_config(target, opt)
	local cfg = _get_cfg(target)
	target:data_set('easy.qmldir.cfg', cfg)

	local basedir = _get_base_dir(target)
	target:data_set('easy.qmldir.base_dir', basedir)

	local outdir = path.join(target:autogendir(), 'rules', '@easy/qmldir', cfg.module_dir)
	local cfg_outdir = target:values('easy.qmldir.outdir')
	if cfg_outdir then
		outdir = path(cfg_outdir)
	end
	target:data_set('easy.qmldir.outdir', outdir)

	target:data_add('easy.qmldir.output_files', path.join(outdir, 'qmldir'))
end

local function _print_progress(options, message)
	cprint(progress_utils.text(options.progress, message))
end

local function _textualize_qmldir(qmldir)
	local qmldir_lines = {}
	for _, line in ipairs(qmldir) do
		table.insert(qmldir_lines, table.concat(line, ' '))
	end
	return (table.concat(qmldir_lines, '\n') .. '\n')
end

function before_build_files(target, sourcebatch, opt)
	local cfg = target:data('easy.qmldir.cfg')
	local basedir = target:data('easy.qmldir.base_dir')
	local inputs = sourcebatch.sourcefiles
	local outfile = target:data('easy.qmldir.output_files')

	local qmldir = {}

	-- module identifier declaration
	table.insert(qmldir, {'module', cfg.module})

	-- plugin declaration
	if cfg.plugin and cfg.plugin ~= '' then
		local plugin = {}

		if cfg.optional_plugin then
			table.insert(plugin, 'optional')
		end

		table.join2(plugin, {'plugin', cfg.plugin})

		if cfg.plugin_path and cfg.plugin_path ~= '' then
			table.insert(plugin, cfg.plugin_path)
		end

		table.insert(qmldir, plugin)
	end

	-- plugin classname
	if cfg.classname and cfg.classname ~= '' then
		table.insert(qmldir, {'classname', cfg.classname})
	end

	-- typeinfo
	if cfg.typeinfo and cfg.typeinfo ~= '' then
		table.insert(qmldir, {'typeinfo', cfg.typeinfo})
	end

	-- designersupported
	if cfg.designersupported then
		table.insert(qmldir, {'designersupported'})
	end

	table.insert(qmldir, {})

	-- depends list
	_add_list(qmldir, 'depends', cfg.depends)

	-- imports list
	_add_list(qmldir, 'import', cfg.imports)

	-- preferred path
	if cfg.prefer and cfg.prefer ~= '' then
		table.insert(qmldir, {'prefer', cfg.prefer})
		table.insert(qmldir, {})
	end

	-- object/resource declarations
	for _, file in ipairs(inputs) do
		local fileconfig = target:fileconfig(file) or {}

		local object = {}

		local fname = path.relative(file, path.join(basedir, cfg.module_dir))
		local object_name = fileconfig.qmldir_name or path.basename(file)

		if fname:match('%.qml') then
			if _is_singleton(file) then
				table.insert(object, 'singleton')
			elseif fileconfig.qmldir_internal then
				-- a special case where we form the full declaration at once, hence `goto`
				table.join2(object, {'internal', object_name, fname})
				goto add_object
			end
		end

		if fname:match('%.qml$') or fname:match('%.js$') or fname:match('%.mjs$') then
			local version = fileconfig.qmldir_version or cfg.version
			table.join2(object, {object_name, version, fname})
		end

		::add_object::
		table.insert(qmldir, object)
	end

	local qmldir_text = _textualize_qmldir(qmldir)
	depend.on_changed(function()
		_print_progress(opt, 'generating.easy.qmldir ' .. outfile)
		io.writefile(outfile, qmldir_text)
	end, {
		values = qmldir_text,
		files = table.join(inputs)
	})
end

function on_config_multiple(target, opt)
	local cfg = _get_cfg(target)
	target:data_set('easy.qmldir.cfg', cfg)

	local basedir = _get_base_dir(target)
	target:data_set('easy.qmldir.base_dir', basedir)

	local inputs = {}
	local batches = target:sourcebatches()['@easy/qmldir']
	if batches then
		inputs = batches.sourcefiles
	end

	local modules = _group_by_module(inputs, basedir)

	local outdir = path.join(target:autogendir(), 'rules', '@easy/qmldir')
	local cfg_outdir = target:values('easy.qmldir.outdir')
	if cfg_outdir then
		outdir = path(cfg_outdir)
	end
	target:data_set('easy.qmldir.base_outdir', outdir)

	for mod, files in pairs(modules) do
		local qmldir_file = path.join(outdir, mod, 'qmldir')
		target:data_add('easy.qmldir.output_files', qmldir_file)

		if cfg.to_qrc then
			target:add('files', qmldir_file, {
				rules = '@easy/qrc',
				qrc_prefix = '/qt/qml',
				qrc_base_dir = path.absolute(outdir),
				always_added = true
			})

			for _, file in ipairs(files) do
				target:add('files', file, {
					rules = '@easy/qrc',
					qrc_prefix = '/qt/qml',
					qrc_base_dir = target:values('easy.qmldir.base_dir') or 'qml',
					always_added = true
				})
			end
		end
	end
end

function before_build_files_multiple(target, sourcebatch, opt)
	local cfg = target:data('easy.qmldir.cfg')
	local basedir = target:data('easy.qmldir.base_dir')
	local outdir = target:data('easy.qmldir.base_outdir')
	local inputs = sourcebatch.sourcefiles

	local qmldirs = {}
	local outfiles = {}
	for mod, files in pairs(_group_by_module(inputs, basedir)) do
		local qmldir = {}

		-- module identifier declaration
		table.insert(qmldir, {'module', table.concat(mod:split('/', {
			plain = true
		}), '.')})

		local designersupported = cfg.designersupported
		local depends = cfg.depends
		local imports = cfg.imports
		local prefer = cfg.prefer

		for _, file in ipairs(files) do
			local fileconfig = target:fileconfig(file) or {}

			if fileconfig.qmldir_designersupported ~= nil then
				designersupported = designersupported or fileconfig.qmldir_designersupported
			end

			if fileconfig.qmldir_depends then
				table.join2(depends, fileconfig.qmldir_depends)
			end

			if fileconfig.qmldir_imports then
				table.join2(imports, fileconfig.qmldir_imports)
			end

			if fileconfig.qmldir_prefer then
				assert(not prefer or prefer == fileconfig.qmldir_prefer)
				prefer = fileconfig.qmldir_prefer
			end

			local object = {}

			local fname = path.relative(file, path.join(basedir, mod))
			local object_name = fileconfig.qmldir_name or path.basename(file)

			if fname:match('%.qml') then
				if _is_singleton(file) then
					table.insert(object, 'singleton')
				elseif fileconfig.qmldir_internal then
					-- a special case where we form the full declaration at once, hence `goto`
					table.join2(object, {'internal', object_name, fname})
					goto add_object
				end
			end

			if fname:match('%.qml$') or fname:match('%.js$') or fname:match('%.mjs$') then
				local version = fileconfig.qmldir_version or cfg.version
				table.join2(object, {object_name, version, fname})
			end

			::add_object::
			table.insert(qmldir, object)
		end

		if designersupported then
			table.insert(qmldir, {'designersupported'})
		end

		-- depends list
		_add_list(qmldir, 'depends', table.unique(depends))

		-- imports list
		_add_list(qmldir, 'import', table.unique(imports))

		-- preferred path
		if prefer and prefer ~= '' then
			table.insert(qmldir, {'prefer', prefer})
		end

		local outfile = path.join(outdir, mod, 'qmldir')
		local qmldir_text = _textualize_qmldir(qmldir)
		depend.on_changed(function()
			_print_progress(opt, 'generating.easy.qmldir ' .. outfile)
			io.writefile(outfile, qmldir_text)
		end, {
			files = table.join(files),
			values = qmldir_text
		})
	end
end
