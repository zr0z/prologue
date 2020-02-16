import httpcore, asyncdispatch, asyncfile, mimetypes, md5
import strtabs, macros, tables, strformat, os, times

import response, pages, constants, cookies
from types import BaseType, Session, SameSite, initSession

import regex


when not defined(production):
  import ../naive/request


type
  PathHandler* = ref object
    handler*: HandlerAsync
    middlewares*: seq[HandlerAsync]
    excludeMiddlewares*: seq[HandlerAsync]

  Path* = object
    route*: string
    httpMethod*: HttpMethod

  Router* = ref object
    callable*: Table[Path, PathHandler]

  RePath* = object
    route*: Regex
    httpMethod*: HttpMethod

  ReRouter* = ref object
    callable*: seq[(RePath, PathHandler)]

  Context* = ref object
    request*: Request
    response*: Response
    router*: Router
    reRouter*: ReRouter
    size*: int
    first*: bool
    middlewares*: seq[HandlerAsync]
    session*: Session

  HandlerAsync* = proc(ctx: Context): Future[void] {.closure, gcsafe.}


proc newContext*(request: Request, response: Response,
    router: Router, reRouter: ReRouter): Context {.inline.} =
  Context(request: request, response: response, router: router,
      reRouter: reRouter, size: 0, first: true, session: initSession(data = newStringTable()))

proc handle*(ctx: Context): Future[void] {.inline.} =
  result = ctx.request.respond(ctx.response)

proc defaultHandler*(ctx: Context) {.async.} =
  let response = error404(body = errorPage("404 Not Found!", PrologueVersion))
  await ctx.request.respond(response)

proc getCookie*(ctx: Context; key: string, default: string = ""): string {.inline.} =
  getCookie(ctx.request, key, default)

proc setCookie*(ctx: Context; key, value: string, expires = "",
  domain = "", path = "", secure = false, httpOnly = false, sameSite = Lax) {.inline.} =
  let cookies = setCookie(key, value, expires, domain, path, secure, httpOnly, sameSite)
  ctx.response.addHeader("Set-Cookie", cookies)

proc setCookie*(ctx: Context; key, value: string,
  expires: DateTime|Time, domain = "", path = "", secure = false,
      httpOnly = false, sameSite = Lax) {.inline.} =
  let cookies = setCookie(key, value, expires, domain, path, secure, httpOnly, sameSite)
  ctx.response.addHeader("Set-Cookie", cookies)

macro getPostParams*(key: string, default = ""): string =
  var ctx = ident"ctx"

  result = quote do:
    case `ctx`.request.reqMethod
    of HttpGet:
      `ctx`.request.getParams.getOrDefault(`key`, `default`)
    of HttpPost:
      `ctx`.request.postParams.getOrDefault(`key`, `default`)
    else:
      `default`

macro getQueryParams*(key: string, default = ""): string =
  var ctx = ident"ctx"

  result = quote do:
    `ctx`.request.queryParams.getOrDefault(`key`, `default`)

macro getPathParams*(key: string): string =
  var ctx = ident"ctx"

  result = quote do:
    `ctx`.request.pathParams.getOrDefault(`key`)

macro getPathParams*[T: BaseType](key: string, default: T): T =
  var ctx = ident"ctx"

  result = quote do:
    let pathParams = `ctx`.request.pathParams.getOrDefault(`key`)
    parseValue(pathParams, `default`)

proc staticFileResponse*(ctx: Context, fileName, root: string, mimetype = "",
    downloadName = "", charset = "UTF-8", headers = newHttpHeaders()) {.async.} =
  let
    mimeDB = newMimetypes()
    filePath = root / fileName
  var
    mimetype = mimetype
    download = false

  if mimetype == "":
    var ext = fileName.splitFile.ext
    if ext.len > 0:
      ext = ext[1 .. ^ 1]
    mimetype = mimeDB.getMimetype(ext)

  # exists -> have access -> can open
  if not existsFile(filePath):
    await ctx.request.respond(error404())
    return

  var filePermission = getFilePermissions(filePath)
  if fpOthersRead notin filePermission:
    await ctx.request.respond(abort(status = Http403,
        body = "You do not have permission to access this file."))
    return

  let
    info = getFileInfo(filePath)
    contentLength = info.size
    lastModified = info.lastWriteTime
    etagBase = fmt"{fileName}-{lastModified}-{contentLength}"
    etag = getMD5(etagBase)

  if downloadName != "":
    var ext = fileName.splitFile.ext
    if ext.len > 0:
      ext = ext[1 .. ^ 1]
      let mimes = mimeDB.getMimetype(ext)
      if mimes != "":
        mimetype = mimes
    headers["Content-Disposition"] = fmt"""attachment; filename="{downloadName}""""
    download = true

  headers["Content-Length"] = $contentLength
  headers["Content-Type"] = mimetype & "; " & charset
  headers["Last-Modified"] = $lastModified
  headers["Etag"] = etag

  if contentLength < 20_000_000:
    # if ctx.request.headers.hasKey("If-None-Match") and ctx.request.headers[
    #     "If-None-Match"] == etag and download == true:
      # await ctx.request.respond(Http304, "")
    # else:
    let body = readFile(filePath)
    await ctx.request.respond(Http200, body, headers)
  else:
    await ctx.request.respond(Http200, "", headers)
    var
      fileStream = newFutureStream[string]("staticFileResponse")
      file = openAsync(filePath, fmRead)
    defer: file.close()

    await file.readToStream(fileStream)

    while true:
      let (hasValue, value) = await fileStream.read()
      if hasValue:
        await ctx.request.send(value)
      else:
        break