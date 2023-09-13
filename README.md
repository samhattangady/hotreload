# hotreload

Running on zig `0.12.0-dev.25+36c57c3ba`

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

The executable loads the dll on startup, and can reload the dll whenever
the `r` key is pressed in the application.

To load the dll, we copy it from `zig-out` to another location to avoid access
clashes when we want to rebuild the library.
We rename the dll to avoid file name clashes. This is the dll that we then
load in.

When we want to build statically, we can turn off the `HOTRELOAD` flag,
and the whole project will compile statically. The changes between the two
modes are minimal. The state for storing dll data in `main.zig` is no longer
required, and we call `game.update()` directly rather than through the dll.

## Running the hot code reload
1. `zig build run` compiles everything and starts the application. You will see a
rectangle bouncing around the screen.

2. Make changes to the `game.zig` file - for example, change the
color of the rectangle in `Game.render` or size and speed in `Game.resetState`.

3. In a new terminal, run `zig.build`. This will throw an error saying `AccessDenied` to
`reload.exe`. This can be ignored.

4. With the application window focussed, press the `r` key. This reloads the dll, and
the application will be updated with the changes made in step 2.

5. GOTO step 2.

6. Profit?

## Current Issues

- Is this the correct approach? I am new to this, and I don't know if there are any
obvious issues that I am unaware of in this space.

- Is hot code swapping planned to release real soon? I think Andrew had streamed about
it a while ago, but I don't know if there have been any updates on that front.

- What is the best way to handle recompiling and reloading? The current approach involves
copying the dll file out of `zig-out/bin`. If we use the dll directly from `zig-out`, then
the next time we try to build the library, the application is already accessing the file, and
we get an `AccessDenied` error.

- Debugging doesn't work cleanly. I use RemedyBG, and I can attach to the running
process. But the breakpoints don't get correctly identified. This might be because
we aren't correctly handling the `.pdb` files, but I am not sure the correct
way to do that. 

According to the docs,
```
Note that RemedyBG will first try to load the PDB that is specified in the binary's header (PE32+).
If this cannot be found, then RemedyBG will make a second attempt to load the PDB file in same
directory as the binary.
```
I don't know how to handle this issue, and which of the two attempts should be looked into.

- Adding more fields to the `Game` struct seems like it is a memory unsafe option. It has worked
a few times, but I think that might just be lucky. 

I would like to know if there is a way to
make that more reliable. The way that I think about it is if I can alloc a large chunk of memory
and then use the head of that to store the game struct, so that any additional fields will all
be in memory that is safe to touch.

Additionally, I think the zig spec does not preserve the ordering of elements in the struct, so
there may be changes needed there, possibly using `extern struct` or `packed struct`.

- We want to automatically detect when a new dll has been compiled and reload
it. Ideally, we would do this using `std.fs.Watch`, but that requires `async`
which is not yet ready in self hosted. I tried to directly call the windows
API, but didn't get too far.

I think I am okay waiting for the async feature to arrive in zig.

- The `build.zig` file is ugly, so when we rebuild just the dll, it tries to rebuild the
executable as well, and fails. This is a smaller issue in the grand scheme.
