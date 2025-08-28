package("lodash.qml")
    set_description("A lodash wrapper for easy use in QML")

    add_urls("https://github.com/easyQML/lodash.qml.git")
    add_versions("4.17", "a86a9c2c8207f208246802dc749eab2af33e8fad")

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
