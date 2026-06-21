fx_version 'cerulean'
game 'gta5'

name 'ciresar'
description 'Cherry picking job — multi-framework (Dunko vRP / QBox / QBCore / ESX). Click cherries, watch them tumble into your basket, sell to the vendor.'
author 'FXServer'
version '2.0.0'

-- Shared so Config + Locales exist on both client and server.
shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/ui-kit.css',
    'html/style.css',
    'html/script.js',
    'html/tree.png',
    'html/cherry.png',
}
