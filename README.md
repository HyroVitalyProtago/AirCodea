# AirCodea

:warning: **Don't use it on projects that haven't backup ! Stability is not well tested yet. So don't hesitate to duplicate your projects before using AirCodea for now.**

## Last release

https://github.com/HyroVitalyProtago/AirCodea/releases/download/v0.1/AirCodea.zip

## Description
AirCodea is my attempt to reproduce AirCode in Codea.
It's actually a prototype with some ideas that are not fully implemented.
It runs a web server based on expressLua (my partial implementation of expressJS but in Lua) with coroutines.
You can fork this project to create your own AirCodea or to contribute to the main project.

Some additional features compared to AirCode:
- You can play/pause (if you use the update callback), enable/disable autoplay and autosave
- Alt-s to save the project (only useful if autosave mode is disabled)
- Alt-r to restart the project
- Alt-t to create a project tab
- Alt-w to remove the current project tab

The autoplay don't restart entirely the project, in other words, it doesn't run again the setup function, but all others variables and functions are updated. This kind of hot-reload allow to keep context between changes.

## Limitations
- only project names without spaces, accents and special characters like '_' works for now
- only projects that you have created are availables
