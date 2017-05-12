## Requeriments:


* SteamWorks -> https://forums.alliedmods.net/showthread.php?t=229556

* Socket -> https://forums.alliedmods.net/showthread.php?t=67640

* Steam account with steam guard disabled. **You should not use your personal account for this, it could be flagged as a spam bot.**


## Installation:


If you use this in **only 1 server** then drag and drop, configure the cvars and you are done.


If you use this in **multiple servers** then you need select 1 server as receptor of all the request.

In the receptor server, drag and drop, configure the cvars and you are done with that server.

In the rest of servers, drag and drop, move morercon.smx from plugins/disabled directory to plugins/ for enable the plugin. Then configure his cvars:
```
sm_morercon_host "151.80.47.226" // Receptor server IP
sm_morercon_port "27016" // Receptor server PORT
sm_morercon_password "password" // Receptor server RCON password
```

The receptor server need to allow rcon connections requests from the others servers.


## If you want to use the "Dev" version, you need to add a database entry to databases.cfg called "autoinviter".



## Cvars:
```
sm_autoinviter_username "" // Steam login username.
sm_autoinviter_password "" // Steam login password.
sm_autoinviter_logging "1" // 1 = enabled. 0 = disabled.
```

**Configure the groups to invite here: configs/franug-autoinviter/franug_autoinviter.cfg (use steamgroup id per section).**


Note: 

Get groupid64 -> https://support.multiplay.co.uk/support/solutions/articles/1000202859-how-can-i-find-my-steam-group-64-id-

Get groupid32 -> https://forums.alliedmods.net/attachment.php?attachmentid=154036&d=1461379861



## Read rules here: https://github.com/Franc1sco/Franug-PRIVATE-PLUGINS
## Dont forget to give me +rep in my steam profile ( http://steamcommunity.com/id/franug ) if you like my plugins :)