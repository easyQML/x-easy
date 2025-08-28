package("lodash.qml")
    set_description("The lodash.qml package")

    add_urls("https://github.com/easyQML/lodash.qml.git")
    add_versions("4.17", "cd8d9e3d78e16dea28924fcf0796507854b4fa26")

    on_install(function (package)
        local configs = {}
        -- if package:config("shared") then
        --     configs.kind = "shared"
        -- end
        import("package.tools.xmake").install(package, configs)
    end)

    on_test(function (package)
        -- TODO check includes and interfaces
        -- assert(package:has_cfuncs("foo", {includes = "foo.h"})
    end)
