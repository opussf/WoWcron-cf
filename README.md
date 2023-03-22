[![Build Status](https://travis-ci.org/opussf/WoWCron.svg?branch=master)](https://travis-ci.org/opussf/WoWCron)

# WoW Cron

Have you ever wanted to have World of Warcraft do an action on a regular schedule?
Call an addon, sort your bags, have an emote run on a schedule.
Maybe even do it once everytime you login (or reload).

Now the power of cron is in your hands, and in WoW.

## What it can do

This addon lets you use the power of cron to call any installed addon, perform an emote, or run something like a macro.
It will also let you /yell, /say, or even make an anouncement in guild chat.

A simple cron string like ```* * * * * /joke``` will have your character do the joke emote every minute.
Anounce your Thursday and Monday guild runs with ```45 18 * * 1,4 /g Guild run starts in 15 minutes.```

### Brief into to cron

For a full introduction to cron, do a search and read some of the great information out there.
The important bit of information, for this document is that cron defines 6 fields that describe a pattern to match against time to see if a command should be run that minute.
The 6 fields of cron are space delimted and are, in order:
```
* * * * * <command>
^ ^ ^ ^ ^
| | | | + - day of week (0 - 6) (Sunday = 0)
| | | + --- month (1 - 12)
| | + ----- day of month (1 - 31)
| + ------- hour (0 - 23)
+ --------- minute (0 - 59)
```

The fields are normally numeric, some implementations support 3 letter abbriviations for month and day of week.
This does not yet work.

There are a few macros for cron, normally starting with the '@' character.
```@hourly```, ```@midnight```, ```@first``` are the only macros currently supported.
```@first``` will only run the very first time after loggin in.

Cron commands are kept in crontabs (cron table).
This addon keeps two active crontabs, one global and one for the current character.

### Allowed commands

The allowed commands can be any of the following:
* Any slash command for any currently installed addon. It should queitly fail if the addon is not installed for your current character.
* Any emote. Note that the emote aliases are not currently supported. (/joke works but not /silly)
* Some basic chat commands.  ```/say```, ```/guild``` or ```/yell``` are currently supported.
* Running some Lua code directly.  Use ```/run``` or ```/script``` as the start of the command to identify code to run.

### Cron Examples

* ```0,15,30,45 * * * * /train``` does the train macro on the quarter hour marks.
* ```*/20 * * * * /run SortBags()``` calls the SortBags() function every 20 minutes.
* ```* * * * * /run wowCron.Print(date("%H:%M"))``` prints the time every minute.
* ```@first /ineed list``` runs the ineed addon with the list command.


### Commands

To keep it simple, there are only a few commands.
All commands work on the current character's crontab by default.
Adding the ```global``` keyword before the command allows one to work with the global crontab.

Commands:
* [global] <cron line> - adds a cron line
* [global] add <cron line> - explict call to add a cron line
* [global] list - lists the lines in the crontab
* [global] rm <index> - removes the <index> line from the crontab
* help - shows a help section.

## Notes

This is still a new addon.
There are still some debug items in the code.
Printing the time on the minute, and showing what it is running.
Feel free to comment out those lines in the code if you don't like them.

I'm also thinking of spending some time with creating a UI for this.
The UI addition would change the command line, and would probably double the size of the addon.



