# hotreload

Running on zig `0.12.0-dev.415+5af5d87ad`

A project to try out hotreloading in zig. Hotreloading means updating an
application that is already running. We do this by using dynamic libraries
which are recompiled, and the running application reloads the library.

## Current Structure
There are two files; `main.zig` and `game.zig`. Both of these files have access
to the `Game` struct which is in the `game.zig` file.

To implement hot reloading, we compile an executable and a dynamic library.
`main.zig` is used to create an executable called `reload.exe` 
and `game.zig` is used to create a dynamic library called `hotreload.dll`.

The dll only exposes the `Game.update` method, so the surface is very
minimal. 

On startup, the executable loads up the directory. It then spawns a thread that
watches the `zig-out/lib` directory. The watcher thread sets a flag when it sees
any change in the output dir, and the main loop sees that flag, and reloads the
`dll`, and updates the pointer to the `updateGame` method.

To load the dll, we copy it from `zig-out` to another location to avoid access
clashes when we want to rebuild the library.

When we want to build statically, we can build with `-Dbuild_mode=static_exe`,
and the whole project will compile statically. The changes between the two
modes are minimal. The state for storing dll data in `main.zig` is no longer
required, and we call `game.update()` directly rather than through the dll.

## Running the hot code reload
1. `zig build run -Dbuild_mode=dynamic_exe` compiles everything and starts 
the application. You will see a rectangle bouncing around the screen.

2. Make changes to the `game.zig` file - for example, change the
color of the rectangle in `Game.render`, or draw more shapes.

3. In a new terminal, run `zig build -Dbuild_mode=hotreload`. Once the compilation
is complete, the running app will automatically load in the new library, and the
app will hotreload.

4. `GOTO` step 2.

5. Profit?

## Current Issues

- Is this the correct approach? I am new to this, and I don't know if there are any
obvious issues that I am unaware of in this space.

- Is hot code swapping planned to release real soon? I think Andrew had streamed about
it a while ago, but I don't know if there have been any updates on that front.

- What is the best way to handle recompiling and reloading? The current approach involves
copying the dll file out of `zig-out/bin`. If we use the dll directly from `zig-out`, then
the next time we try to build the library, the application is already accessing the file, and
we get an `AccessDenied` error.

- Adding more fields to the Game struct seems like it is not memory safe. It has worked
a few times, but I think that might just be lucky.

I would like to know if there is a way to
make that more reliable. The way that I think about it is if I can alloc a large chunk of memory
and then use the head of that to store the game struct, so that any additional fields will all
be in memory that is safe to touch.

Additionally, I think the zig spec does not preserve the ordering of elements in the struct, so
there may be changes needed there, possibly using `extern struct` or `packed struct`.

[Discussion on Ziggit](https://ziggit.dev/t/hotreloading-in-zig/1737)
