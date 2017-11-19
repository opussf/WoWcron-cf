* * * * * <command>
^ ^ ^ ^ ^
| | | | + - day of week (0 - 6) (Sunday = 0)
| | | + --- month (1 - 12)
| | + ----- day of month (1 - 31)
| + ------- hour (0 - 23)
+ --------- minute (0 - 59)

@first    = run once after the first login
@hourly   = 0 * * * *
@midnight = 0 0 * * *

<command> = "/<addon command>" | "/<emote token>" | "/run | /script" <lua code> | "/say | /guild | /yell"

/cron [global] <add | list | rm <index>> <cron entry>

Examples:
/cron global list
/cron global rm 1
/cron add * * * * * /yell Hello
/cron add */10 * * * * /run SortBags()
/cron add @first /cron list


Specials:
Turn on the 'debug' setting to see what is happening when a pattern should match:
```/script wowCron.debug=true```