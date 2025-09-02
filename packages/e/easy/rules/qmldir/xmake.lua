rule('qmldir')
	set_extensions('.qml', '.js', '.mjs')
	add_deps('@easy/qrc')
	add_orders('@easy/qmldir', '@easy/qrc', 'qt.qmlplugin')

	on_config(function (target, opt)
		if target:values('easy.qmldir.multiple_modules') then
			import('qmldir').on_config_multiple(target, opt)
		else
			import('qmldir').on_config(target, opt)
		end
	end)

	before_build_files(function (target, sourcebatch, opt)
		if target:values('easy.qmldir.multiple_modules') then
			import('qmldir').before_build_files_multiple(target, sourcebatch, opt)
		else
			import('qmldir').before_build_files(target, sourcebatch, opt)
		end
	end)
