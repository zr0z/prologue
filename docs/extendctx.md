# Extend Context

`Prologue` provides flexible way to extend `Context`. `User-defined Context` should inherit from the `Context` from `Prologue`.

You may want to add an int to `Context`:


```nim
import prologue
import std/strformat


type
  UserContext = ref object of Context
    data: int


proc hello*(ctx: UserContext) {.async.} =
  inc ctx.data
  echo fmt"{ctx.data = }"
  resp "<h1>Hello, Prologue!</h1>"

var app = newApp()
app.use(extendContextMiddleWare(UserContext))
app.get("/", hello)
app.run()
```

You may want to write a middleware:

```nim
import prologue
import std/strformat


type
  UserContext = ref object of Context
    data: int

  ExperimentContext = concept ctx
    ctx is Context
    ctx.data is int


proc experimentMiddleware[T: ExperimentContext](ctxType: typedesc[T]): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    inc ctx.ctxType.data
    echo fmt"{ctx.ctxType.data = }"
    await switch(ctx)

proc hello*(ctx: UserContext) {.async.} =
  inc ctx.data
  echo fmt"{ctx.data = }"
  resp "<h1>Hello, Prologue!</h1>"

var app = newApp()
app.use(extendContextMiddleWare(UserContext))
app.use(experimentMiddleware(UserContext))
app.get("/", hello)
app.run()
```
