import streams
import options as opt
from strutils import toUpperAscii

import libcurl
import ezutils

import common

type HttpMethod* {.pure.} = enum
  HM_GET,
  HM_HEAD,
  HM_POST,
  HM_PUT,
  HM_DELETE

type Easy* = object
  raw: PCurl
  reads, writes: opt.Option[Stream]

type EasyError* = object of IOError

template intoEasyError(err: Code) =
  let ret = err
  if ret != E_OK:
    raise newException(EasyError, $easy_strerror(ret))

proc `=destroy`(self: var Easy) =
  self.raw.easy_cleanup()
  self.raw = nil

proc `=copy`(self: var Easy, rhs: Easy) {.error.}

proc initCurlEasy*(): Easy {.genrefnew.} =
  result.raw = easy_init()

proc perform*(self: Easy) {.genref.} =
  intoEasyError self.raw.easy_perform()

proc `method=`*(self: Easy, kind: HttpMethod) {.genref.} =
  case kind:
  of HM_GET:
    intoEasyError easy_setopt(self.raw, OPT_HTTPGET, true)
  of HM_POST:
    intoEasyError easy_setopt(self.raw, OPT_POST, true)
  of HM_PUT:
    intoEasyError easy_setopt(self.raw, OPT_PUT, true)
  of HM_DELETE:
    intoEasyError easy_setopt(self.raw, OPT_CUSTOMREQUEST, "DELETE")
  of HM_HEAD:
    intoEasyError easy_setopt(self.raw, OPT_NOBODY, true)

proc `method=`*(self: Easy, kind: string) {.genref.} =
  intoEasyError easy_setopt(self.raw, OPT_CUSTOMREQUEST, kind.toUpperAscii)

proc `write=`*(self: var Easy, stre: Stream) {.genref.} =
  self.writes = some stre
  intoEasyError easy_setopt(self.raw, OPT_WRITEDATA, addr self)
  intoEasyError easy_setopt(self.raw, OPT_WRITEFUNCTION) do (
      buffer: cstring,
      size: int,
      count: int,
      self: ptr Easy) -> int {.cdecl.}:
    let stream = self[].writes.unsafeGet()
    result = size * count
    if result == 0:
      stream.flush()
    else:
      stream.writeData(buffer, result)

proc `read=`*(self: var Easy, stre: Stream) {.genref.} =
  self.reads = some stre
  intoEasyError easy_setopt(self.raw, OPT_READDATA, addr self)
  intoEasyError easy_setopt(self.raw, OPT_READFUNCTION) do (
      buffer: pointer,
      size: int,
      count: int,
      self: ptr Easy) -> int {.cdecl.}:
    let stream = self[].writes.unsafeGet()
    result = size * count
    result = stream.readData(buffer, result)

template `.=`*(self: Easy, field: untyped, value: untyped): untyped =
  const fieldname = astToStr(field)
  when fieldname =!= "verbose":
    intoEasyError easy_setopt(self.raw, OPT_VERBOSE, bool value)
  elif fieldname =!= "url":
    intoEasyError easy_setopt(self.raw, OPT_URL, cstring value)
  elif fieldname =!= "port":
    intoEasyError easy_setopt(self.raw, OPT_PORT, clong value)
  elif fieldname =!= "timeout":
    intoEasyError easy_setopt(self.raw, OPT_TIMEOUT_MS, int value)
  elif fieldname =!= "referer":
    intoEasyError easy_setopt(self.raw, OPT_REFERER, cstring value)
  elif fieldname =!= "useragent":
    intoEasyError easy_setopt(self.raw, OPT_USERAGENT, cstring value)
  elif fieldname =!= "follow":
    intoEasyError easy_setopt(self.raw, OPT_FOLLOWLOCATION, bool value)
  elif fieldname =!= "maxredirs":
    intoEasyError easy_setopt(self.raw, OPT_MAXREDIRS, int value)
  else:
    {.error: "unknown field: " & fieldname.}

template `.=`*(self: ref Easy, field: untyped, value: untyped): untyped =
  `.=`(self[], field, value)

template `.`*(self: Easy, field: untyped): untyped =
  const fieldname = astToStr(field)
  when fieldname =!= "url":
    var name: cstring
    intoEasyError easy_getinfo(self.raw, INFO_EFFECTIVE_URL, addr name)
    name
  elif fieldname =!= "method":
    var name: cstring
    intoEasyError easy_getinfo(self.raw, INFO_EFFECTIVE_METHOD, addr name)
    name
  elif fieldname =!= "response":
    var code: clong
    intoEasyError easy_getinfo(self.raw, INFO_RESPONSE_CODE, addr code)
    code
  elif fieldname =!= "content_type":
    var name: cstring
    intoEasyError easy_getinfo(self.raw, INFO_CONTENT_TYPE, addr name)
    name
  else:
    {.error: "unknown field: " & fieldname.}

template `.`*(self: ref Easy, field: untyped): untyped = `.`(self[], field)
