# project-zomboid-asset-creator

An attempt at making a Project Zomboid Asset Creator/Editor to enable development of mods a lot easier. This is currently using Godot as the "engine" to do everything, don't really want to create from scratch lol.

# THIS IS A HEAVY WORK IN PROGRESS TOOL AND WILL REQUIRE CONSTANT UPDATES WHEN TIS UPDATES THEIR GAME!

Like I mentioned, its to make development of mods easier. I have struggled with mod making in PZ due to how weird it is, at least for me, and with the recent release of Hytale and its intergrated Asset Editor, I thought why not make a third party tool. This tool will:
- Start off by finding/requesting for the Zomboid steam folder so it can read all the scripts
- Create the mod folder setup for you so everything is ready to go - including a mod.info setup, correct file structures, temp images
- Make coding easier
    - Hopefully have ZedScript (Script Syntax) and Umbrella (Lua Syntax) baked in somehow
    - Bake in the JavaDocs for easy snippets
    - * * should i just make my own coding language called ZombieCode or something? * *
- Make viewing of items a lot easier
- many more things
    - cant wait to scope creep this!

## ToDo:
Note: all editing of files will be made as a "copy" to the users mod structure
- Intergrate file view
    - a neat way of doing it so its not all messy goop for a lot of people (lol)
- Automatic File Structuing
- Intergrate file editing
    - Unsure on the route I will do for this
    - I do want to make sure ZedScript and Umbrella is added as well
    - Snippets from the JavaDocs as well??
- Image importing
- Image editing??
- Model editing??
- Add more to the todo list (lol)

## Change Log
08/02/2026 - Started coding the project, started with a file loader system that will hopefully load all of the Scripts
09/02/2026 - Nuked the project. Restarting the project from scratch. Needing to simplify things down first.