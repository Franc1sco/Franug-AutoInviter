## Requeriments:


* SteamWorks -> http://users.alliedmods.net/~kyles/builds/SteamWorks/

* Socket -> https://forums.alliedmods.net/showthread.php?t=67640

* SMJansson extension (.dll for Windows and .so for Linux) -> https://github.com/thraaawn/SMJansson/tree/master/bin

* Steam account (not your main account).

## Setting Account

After you have installed the plugin you need to configure the Steam account's credentials, to do so open sourcemod/configs/franug-autoinviter/franug_login.cfg and input the accounts credentials in the file, an example would be this:
```
"franug_login"
{
	"username"	"testaccountname789"
	"password"	"arandompassword123"
}
```
Use alphanumeric user/pass, max length: 32 characters

Now to login to Steam servers you need join the server as a player and from console or chat (i recommend console) input the next command:

sm_autoinviter_send_code or from chat /autoinviter_send_code

This will send a Steam Guard code to the configured e-mail of the account. Copy the code and input the next command with the code:

sm_autoinviter_input_code YOURCODE

If everything is right, you should have now completed the setup process, if not use the command sm_autoinviter_last_error to check the last error in the errors table.


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


## Cvars for the autoinviter:

```
sm_franugautoinviter_chatmsg "Thanks for play in the Cola-Team community servers. Please accept the group invite that I sent you for keep you updated about out servers :)" // msg when the bot invite to someone
sm_franugautoinviter_removefriends "0" // Removes friends after inviting them to group.
```


## Also you need to add a database entry to databases.cfg called "autoinviter".


**Configure the groups to invite here: configs/franug-autoinviter/franug_autoinviter.cfg (use steamgroup id per section).**


Note: 

Get groupid64 -> https://support.multiplay.co.uk/support/solutions/articles/1000202859-how-can-i-find-my-steam-group-64-id-

Get groupid32 -> https://forums.alliedmods.net/attachment.php?attachmentid=154036&d=1461379861



## Read rules here: https://github.com/Franc1sco/Franug-PRIVATE-PLUGINS
## Dont forget to give me +rep in my steam profile ( http://steamcommunity.com/id/franug ) if you like my plugins :)