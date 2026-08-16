fx_version "cerulean"
use_experimental_fxv2_oal "yes"
author "zykem"
version "1.0.0"
game "gta5"
lua54 "yes"

dependencies {
    "ox_lib",
    "oxmysql"
}

shared_scripts {
    "@ox_lib/init.lua",
    "types.lua"
}

client_scripts {
    "client/main.lua",
    "client/modules/admin.lua"
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "server/main.lua"
}

files {
    "config.lua",
    "shared/debugPrint.lua",
    "client/modules/*.lua",
    "sql/schema.sql",
    "web/dist/index.html",
    "web/dist/**/*"
}

ui_page 'web/dist/index.html'
--ui_page "http://localhost:5173"