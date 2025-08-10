A simple attempt at implementing a very basic version of Tetris in Zig using Raylib.

The purpose of this repository, was to test out different AI Agents, such as Github Copilots agents mode.

The project has been mostly coded using agents, and i've only made minor refactors / syntax fixes.

The project is using Zig 0.14.0.
Should be runnable by simply pulling the repository and running `zig build run` in the terminal.

TODO:
- Drawing blocks in the sidebar uses grid positioning, which means i currently can only 
draw the blocks in spaces of 40px. This is not ideal, as aligning the "I" block with other 
blocks in the preview requires a 20px offset.
- Blocks should fall faster as the game progresses.
- Leaderboard system / saving highscores is missing.
