rule('qrc')
	add_orders('@easy/qsb', '@easy/qmldir', '@easy/qrc', 'qt.qrc')
	on_config(function(target)
        local qrcfile = path.join(target:autogendir(), 'rules', '@easy/qrc', target:name() .. '.qrc')
		target:data_set('easy.qrc.file', qrcfile)
		target:add('files', qrcfile, {always_added = true})
	end)

    before_build(function(target, options)
		local qrcfile = target:data('easy.qrc.file')

		local resource_files = {}
		local batches = target:sourcebatches()['@easy/qrc']
		if batches then
			resource_files = batches.sourcefiles or {}
		end
		table.sort(resource_files)

		local prefix_groups = {}
		for _, f in ipairs(resource_files) do
			local fileconfig = target:fileconfig(f)
			if fileconfig then
				local prefix = fileconfig.qrc_prefix or path.join('/', path.relative(target:scriptdir(), os.projectdir()))
				if not prefix_groups[prefix] then
					prefix_groups[prefix] = {}
				end
				table.insert(prefix_groups[prefix], table.join(fileconfig, {name = f, qrc_prefix = prefix}))
			end
		end

        import('core.project.depend')
		import("utils.progress", {alias = "progress_utils"})

		local dep_values = {}
		for _, v in pairs(prefix_groups) do
			for _, f in ipairs(v) do
				table.insert(dep_values, table.concat({
					f.name,
					'qrc_prefix=' .. tostring(f.qrc_prefix),
					'qrc_base_dir=' .. tostring(f.qrc_base_dir)
				}, '|'))
			end
		end
		table.sort(dep_values)

		os.mkdir(path.directory(qrcfile))
        depend.on_changed(function ()
			cprint(progress_utils.text(options.progress, 'generating.easy.qrc ' .. qrcfile))
            local xml = {'<?xml version="1.0" encoding="UTF-8"?>', '<RCC>'}
			for prefix, pfiles in pairs(prefix_groups) do
				table.insert(xml, '  <qresource prefix="' .. prefix .. '">')

				for _, f in ipairs(pfiles) do
					local name = f.name
					if not path.is_absolute(name) then
						name = path.absolute(name, os.projectdir())
					end

					local base_dir = f.qrc_base_dir or target:scriptdir()
					if not path.is_absolute(base_dir) then
						base_dir = path.absolute(base_dir, target:scriptdir())
					end

					local alias = path.relative(name, base_dir)
					table.insert(xml, string.format('    <file alias="%s">%s</file>', alias, name))
				end
				table.insert(xml, '  </qresource>')
			end
			table.insert(xml, '</RCC>\n')
            io.writefile(qrcfile, table.concat(xml, '\n'))
        end, {files = table.join(resource_files, qrcfile), values = dep_values})
    end)
