import streams

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

proc `method=`*(self: Easy, kind: HttpMethod) =
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

proc `write=`*(self: Easy, stre: Stream) =
  intoEasyError easy_setopt(self.raw, OPT_WRITEDATA, stre)
  intoEasyError easy_setopt(self.raw, OPT_WRITEFUNCTION) do (
      buffer: cstring,
      size: int,
      count: int,
      outstream: Stream) -> int {.cdecl.}:
    result = size * count
    if result == 0:
      outstream.flush()
    else:
      outstream.writeData(buffer, result)

proc `read=`*(self: Easy, stre: Stream) =
  intoEasyError easy_setopt(self.raw, OPT_READDATA, stre)
  intoEasyError easy_setopt(self.raw, OPT_READFUNCTION) do (
      buffer: pointer,
      size: int,
      count: int,
      instream: Stream) -> int {.cdecl.}:
    result = size * count
    result = instream.readData(buffer, result)

template `.=`*(self: Easy, field: untyped, value: untyped) =
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
  else:
    {.error: "unknown field: " & fieldname.}

template `.=`*(self: ref Easy, field: untyped, value: untyped) = `.=`(self[], field, value)