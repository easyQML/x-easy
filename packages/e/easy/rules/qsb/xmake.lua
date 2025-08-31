rule('qsb')
	add_deps('qt.env')
	set_extensions('.comp', '.frag', '.tesc', '.tese', '.vert')
	on_config(function(target)
		import('core.base.semver')
		import('lib.detect.find_file')

		-- get qt
		local qt = assert(target:data('qt'), 'Qt not found!')

		-- get qt sdk version
		local qt_sdkver = nil
		if qt.sdkver then
			qt_sdkver = semver.new(qt.sdkver)
		else
			raise('Qt SDK version not found, please run `xmake f --qt_sdkver=xxx` to set it.')
		end

		-- there was no qsb before Qt 6
		if qt_sdkver:ge('6.0') then
			-- get Qt Shader Baker
			local search_dirs = {}
			if qt.bindir_host then table.insert(search_dirs, qt.bindir_host) end
			if qt.bindir then table.insert(search_dirs, qt.bindir) end
			if qt.libexecdir_host then table.insert(search_dirs, qt.libexecdir_host) end
			if qt.libexecdir then table.insert(search_dirs, qt.libexecdir) end
			local qsb = find_file(is_host('windows') and 'qsb.exe' or 'qsb', search_dirs)
			assert(os.isexec(qsb), 'qsb not found!')

			-- save qsb
			target:data_set('qt.qsb', qsb)

			local gendir = path.join(target:autogendir(), 'rules', '@easy', 'qsb')
			target:data_set('easy.qsb.gendir', gendir)

			local sourcefiles = {}
			local batches = target:sourcebatches()['@easy/qsb']
			if batches then
				sourcefiles = batches.sourcefiles or {}
			end

			for i, sourcefile in ipairs(sourcefiles) do
				local sourcefile_qsb = path.join(
					gendir,
					path.relative(path.directory(sourcefile), target:scriptdir()),
					path.filename(sourcefile) .. '.qsb'
				)
				local fileconfig = target:fileconfig(sourcefile)

				target:add('files', sourcefile_qsb, {
					rules = '@easy/qrc',
					qrc_prefix = fileconfig.qrc_prefix or '/qt/qml',
					qrc_base_dir = path.absolute(path.join(gendir, fileconfig.qrc_base_dir or 'qml')),
					always_added = true
				})
			end
		end
	end)

	on_buildcmd_file(function (target, batchcmds, sourcefile_shader, opt)
		local qsb = target:data('qt.qsb')
		if not qsb then
			-- not on Qt 6, so nothing to do
			return
		end

		local gendir = target:data('easy.qsb.gendir')

		local extra = target:fileconfig(sourcefile_shader)

		local defines = {}
		if extra.defines then
			for _, def in ipairs(extra.defines) do
				table.insert(defines, '-D' .. def)
			end
		end

		local flags = extra.qsb_flags or {'--qt6'}

		local sourcefile_qsb = path.join(
			gendir,
			path.relative(path.directory(sourcefile_shader), target:scriptdir()),
			path.filename(sourcefile_shader) .. '.qsb'
		)

		batchcmds:mkdir(path.directory(sourcefile_qsb))
		batchcmds:show_progress(opt.progress, '${color.build.object}compiling.easy.qsb %s', sourcefile_shader)
		batchcmds:vrunv(qsb, table.join(
			flags,
			defines,
			{
				'-o', sourcefile_qsb,
				sourcefile_shader
			}
		))

		-- add deps
		batchcmds:add_depfiles(sourcefile_shader)
		batchcmds:set_depmtime(os.mtime(sourcefile_qsb))
		batchcmds:set_depcache(target:dependfile(sourcefile_qsb))
	end)
