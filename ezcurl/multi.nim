import bindings
import easy
import ezutils

type Multi* = object
  raw*: PM
  handles: seq[ref Easy]

type MultiError* = object of IOError

proc translateMCode(code: MCode): string =
  case code:
  of M_OK: "ok"
  of M_BAD_HANDLE: "bad handle"
  of M_BAD_EASY_HANDLE: "bad easy handle"
  of M_OUT_OF_MEMORY: "out of memory"
  of M_INTERNAL_ERROR: "internal error"
  of M_BAD_SOCKET: "bad socket"
  of M_UNKNOWN_OPTION: "unknown option"
  else: "unknown error"

template intoMultiError(err: MCode) =
  let ret = err
  if ret != M_OK:
    raise newException(MultiError, translateMCode(err))

proc `=destroy`*(self: var Multi) =
  for handle in self.handles:
    intoMultiError multi_remove_handle(self.raw, handle.raw)
  self.handles.setLen 0
  intoMultiError self.raw.multi_cleanup()
  self.raw = nil

proc `=copy`*(self: var Multi, rhs: Multi) {.error.}

proc initCurlMulti*(): Multi {.genrefnew.} =
  result.raw = multi_init()

proc add*(self: var Multi, rhs: ref Easy) {.genref.} =
  intoMultiError multi_add_handle(self.raw, rhs.raw)
  self.handles.add rhs

proc perform*(self: Multi) {.genref.} =
  var running: int32
  while true:
    intoMultiError self.raw.multi_perform(running)
    if running == 0: return
    var numfds: int32
    intoMultiError self.raw.multi_poll(nil, 0, 1000, numfds)
