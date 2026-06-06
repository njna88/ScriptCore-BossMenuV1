fx_version 'cerulean'

game 'gta5'

author 'ScriptCore.dk'
description 'ScriptCore.dk - BossMenu Version 1.0.0'
contact 'https://discord.gg/ScriptCore-dk'

version '1.0.0'

shared_scripts {

    'config.lua'

}

client_scripts {

    'client.lua'

}

server_scripts {

    '@mysql-async/lib/MySQL.lua', 

    'server.lua'

}

ui_page 'html/index.html'

files {

    'html/index.html',

    'html/style.css',

    'html/script.js'

}

