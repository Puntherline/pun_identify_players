## Disclaimer
This resource is unsupported because it's not really meant to be a proper release, just some code example bits for people who know how to code.

## What it does
It checks your database (via new table from `import_me.sql`) if any identifiers that FiveM provides match to an account that's already banned on your server. This includes the following identifiers:
- Steam
- License
- Xbox Live App
- Xbox Live Account
- Discord
- FiveM Account
- FiveM Tokens
- Resource KVP's

So all in all, it's almost as good as it can be. However, it's missing stuff like the ability to ban and unban players, but if you know how to code you can easily implement those too, or implement some of the functions from this resource into your own resources.

## Requirements
- Either [mysql-async](https://github.com/brouznouf/fivem-mysql-async/releases) or [oxmysql](https://github.com/overextended/oxmysql/releases)

## Installation
- Import the SQL file into your database (Make a backup just in case)
- Add resource to `server.cfg`
- Start your server and you should be able to join.
