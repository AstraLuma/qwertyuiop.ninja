---
layout: post-text
title: "Lunar Eclipse: Attempt the First"
tags: lunar-eclipse, lua
excerpt_separator: <!--more-->
---

I picked up the fantasy computer brain worm: Lunar Eclipse, with a Lua userspace and running on an ESP32-P4 and ESP32-C5. So how's that going?

<!--more-->

([The source for this post is on git.gay](https://git.gay/AstraLuma/lunar-eclipse/src/branch/failed-c-trial/).)


The Structure
=============

The thought was to build usable computer with about the vague UX of the 80's (ie, dawn of GUI on personal computers, but text mode extremely common). I got it in my head to use the ESP32-P4 as a big processor, and the ESP32-C5 as a network-focused secondary CPU. A bunch of other details and design thoughts are in [the repo](https://git.gay/AstraLuma/lunar-eclipse/src/branch/failed-c-trial/).

I wanted to use Lua as the "userspace" language because I Just Think It's Neat, and as I dug into the C API, it occurred to me that I could do a lot by just leaning into Lua (in particular, Lua's async/coroutine system). And as I dug into it, I was having a lot of fun creating, so it became my primary "free time" project.


The Good
========

Lua, both the language and the implementation, are as hackable as its reputation. One of the big successes is supplementing the builtin string error system with a structured error system that I can utilize later. (That is, errors have hierarchal categories, error instances carry data around, including the stacktrace, and error instances are modeled on structlog: message and metadata.)

The value stack system for C often requires juggling, and I did find some features fought (eg, table iteration and the buffer string builder). But overall, as I mastered it, it got easier.

Overall, it was relatively easy for me (who has limited experience in C) to implement a basic REPL, a virtual filesystem, a ROM filesystem driver, errors, and a few dev tools. Overall, getting to this point took about three weeks.


The Bad
=======

Lua's coroutine system in C is callback based: every operation that could potentially yield, you need split your C function across the yield points, and string together the callbacks and the context struct(s).

This is extremely boilerplate-heavy, to the point I considered preprocessor shenanigans to alleviate it.

It was also a royal pain in the ass to debug some extraneous `&` I had accidentally included.

This system also strongly limits what libraries I can include. [LittleFS](https://github.com/littlefs-project/littlefs) was out because of the callback requirements, opting instead for [AsyncFatFS](https://github.com/thenickdude/asyncfatfs).


The Ugly
========

The rub is that large portion of PUC-Rio Lua itself is not written to be async capable. The mistake is that the easy path is to not allow yields. It's so, _so_ much easier to just not. So any time you see in the docs that it might call `__tostring()` or `__index()`, that's a transition from yieldable to not. (That is, your implementation of `__tostring()` is fundamentally not allowed to do IO.) Which, like, is probably fine. Most of the metamethods probably shouldn't be doing IO, so it would probably be fine to make that a rule.

But then we have `__close()`.

Added in 5.4, along with variable declaration attributes, `local <close>` / `__close()` is a system of explicit resource management not dependent on the garbage collector. (That is, you can easily describe when specifically a resource is cleaned up, instead of "whenever the garbage collector deallocates it".) Which works by calling the appropriate `__close()` metamethods when a chunk (function, module, REPL input) finishes executing.

Which leads to two facts:

1. The yieldability of `__close()` is strongly influenced by how the containing block was called.
2. If there's a metamethod that needs to do IO, it's `__close()` (flushing file contents, sending connection close packets, cleaning up temp files, sending messages over IPC, etc)

I could maybe paper over some of that, by only allowing `<close>` in yieldable contexts (which sounds like a rake I'm going to continuously step on), or by creating a system for spawning tasks from non-yieldable contexts (which sounds bad for error reporting, lessons from structured concurrency).

But ultimately, while you can kinda add async to PUC-Rio Lua, it's not made for it.


What Went Wrong
===============

Ok, so explain the crux of this issue more specifically, let's explain async in PUC-Rio Lua.

On the Lua side, it's fairly straight forward:

```lua
-- This is an exremely mocked-up version of an async system
function do_a_thing(what)
    fut = start_thing(what)
    result = coroutine.yield(fut)
    return process_thing(result)
end

function task()
    do_thing(42)
    do_thing(69)
end

function not_async_loop()
    t = coroutine.create(task)
    vals = {}
    while true do
        fut = coroutine.resume(t, vals)
        fut.join()
        vals = fut.results()
    end
end
```

The problem is that the C version is extremely non-trivial: everything eventually leads to `lua_yieldk()` or `lua_callk()`/`lua_pcallk()`, all of which return their results via callbacks.

So this is the worst kind of [colored async](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/): not only are async and sync functions fundamentally different, but the async versions are extremely difficult to use.

What do I mean?

Here's the relatively straight-forward code to load a Lua module ([source](https://git.gay/AstraLuma/lunar-eclipse/src/commit/dce82db4753ea42c00b23885d69c96c8fe9f4d8d/src/libpackage.c#L70-L93)):

```c
static int searcher_Lua_1(lua_State *L, int status, lua_KContext ctx);
static int searcher_Lua_2(lua_State *L, int status, lua_KContext ctx);

static int searcher_Lua (lua_State *L) {
  size_t name_len;
  const char *name = luaL_checklstring(L, 1, &name_len);

  return luaLE_openk(L, name, name_len, O_READ|O_START, 0, searcher_Lua_1);
}

static int searcher_Lua_1(lua_State *L, int status, lua_KContext ctx) {
  size_t name_len;
  const char *name = lua_tolstring(L, 1, &name_len);
  return luaLE_readk(L, -1, 0, ctx, searcher_Lua_2);
}

static int searcher_Lua_2(lua_State *L, int status, lua_KContext ctx) {
  size_t buff_len;
  l_string_t buff = lua_tolstring(L, -1, &buff_len);
  l_string_t name = lua_tostring(L, 1);
  return checkload(L, (luaL_loadbufferx(L, buff, buff_len, name, "bt") == LUA_OK), name);
}
```

I call this straight-forward because it's able to keep all its state on the value stack, and the control flow is strictly linear. I'll leave it to the imagination of the reader to imagine what it would look like if these weren't true (or just look farther down the file at [`findloaderk()`](https://git.gay/AstraLuma/lunar-eclipse/src/commit/dce82db4753ea42c00b23885d69c96c8fe9f4d8d/src/libpackage.c#L109-L181))

And because this system acts as colored async, any function that calls a callback-based operation must itself use callbacks.

And properly, anything that potentially invokes Lua code should be async and use callbacks. Including fundamental operations like `lua_geti()`/`lua_getfield()` (they might call `__index()`) or `lua_getstring()` (might invoke `__tostring()`).

The practical upshot is that, as is the way of colored async, _everything_ needs to be async. Which in this system becomes extremely difficult to write anything.

If I got extremely creative with C and its macro system (or just wrote my own), the best I could hope for is "somewhat less clunky" or maybe "differently clunky".


So What Now?
============

I don't have it in my heart to abandon this project yet. So how do I bridge this?

Start Hacking on C
------------------

I can maybe make a kinda acceptable developer experience for callback async in C by applying sufficient macro crimes. I'm pretty nervous if the standard preprocessor is sophisticated enough to make this good. (eg, I would love to have macros defining macros, or some other way to keep track of context.)

But then I'd have to start ripping out and re-implement much of the Lua standard library (eg, a _lot_ of it uses table indexing, and even more stringifies values). The result of which would practically be a hard fork of PUC-Rio Lua, since bringing in patches from upstream would be too difficult a task to actually do.

The net result would be basically the removal of sync capabilities of Lua, since any call at all could potentially invoke `<close>` / `lua_closeslot`. Which means _everything_ would return-by-callback.

Reimplement in Rust
-------------------

Do you know what Rust does? Allow you to declare functions as async, and recompile those functions as state machines.

Do you know what Rust has? A bunch of ecosystem built on that async support.

Not gonna lie, I was really looking forward to implementing basic OS stuff. But the ecosystem is extremely compelling, and solves problems I'm only secondarily interested in.


What I'll Do
============

I'm still emotionally coming to grips with this.

I know the smart choice is to go with Rust: this ecosystem already exists and does the hardest parts for me. I won't need to fundamentally fight everything forever, and I can get to the bit where I actually try using this system to do things.

But I'm intimidated by Rust, I was looking forward to implementing some of these bits, and I'm worried about the baggage they'll bring.

First, my few forrays into Rust have been rough. It's an extremely Correctness language, which means you spend a lot of time ... refining your ideas until they fit into Rust's (and your libraries) paradigms.

Second, I was having fun puzzling over how to manage task waits and Futures and building the right async primitives to allow a flourishing garden of abstractions. I liked the freedom of picking what I thought would be best for this, not what the ecosystem had decided was "good". (Errors were heavily inspired by Python. I reimplemented `require()` closer to JavaScript. The filesystem is closer to Windows than Unix, but still not really either. And while I originally was going to implement JS-style Promises, I eventually decided to cut off the callbacks and just have data-carrying Futures.) I'm a little nervous a bunch of that will be decided (wrongly) for me, and changing it means hacking on too many libraries.

Finally, I explicitly wanted a non-realtime system, thinner and closer to Lua. I didn't want an RTOS with a Lua bolted on top; I wanted to build a Lua OS.

What I really want out of this, though, is a space to explore the fundamental abstractions we use in computing. What if I reevaluated how the filesystem works? Or the semantics of async? Can I synthesize the lessons of the last few decades into a new environment without the baggage? Which probably means using a language like Rust, that at least has an actually-interesting macro system, even if I slowly vendor and rewrite everything.


What's Next
===========

Research. I've been posting about my progress so far on fedi as [#LunarEclipseComputer](https://tacobelllabs.net/tags/LunarEclipseComputer), and will continue to do so.

Using something like Embassy and its ecosystem is probably the smart choice, so I can spend less time fighting basic hardware and more time exploring "How to organize a computer system". A brief look at esp-rs and Embassy advertises network stacks and USB and DFU, all of which I'll need and are annoying problems to solve and even harder problems to debug. The trick is finding a Lua implementation that's also threaded for async. There's many crates for Lua, but most of them just bundle PUC-Rio Lua, leading back to the problems that spawned this whole post. (Additionally, I want to hack on Lua's standard library, because while I'm building something that could maybe pass as a PC if you squint, I am _not_ conforming to the assumptions of modern PC. Which isn't a hard problem, but probably means more forking & vendoring.)
