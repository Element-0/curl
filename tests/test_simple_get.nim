import ../ezcurl
import unittest
import streams
import json
import options

proc dumpStream(s: Stream): string =
  s.setPosition 0
  s.readAll()

suite "easy":
  setup:
    var easy = newCurlEasy()

  test "simple":
    discard easy
  test "null ua":
    easy.url = "http://nghttp2.org/httpbin/user-agent"
    var ss = newStringStream("")
    easy.write = ss
    easy.perform()
    check easy.response == 200
    let ret = parseJson(ss.dumpStream())
    check ret == %* { "user-agent": nil }
  test "curl ua":
    easy.url = "http://nghttp2.org/httpbin/user-agent"
    easy.user_agent = "ezcurl"
    var ss = newStringStream("")
    easy.write = ss
    easy.perform()
    let ret = parseJson(ss.dumpStream())
    check easy.response == 200
    check ret == %* { "user-agent": "ezcurl" }
  test "redirect":
    easy.url = "http://nghttp2.org/httpbin/redirect-to?url=user-agent"
    easy.user_agent = "ezcurl"
    easy.follow = true
    easy.maxredirs = 5
    var ss = newStringStream("")
    easy.write = ss
    easy.perform()
    check easy.response == 200
    check easy.url == "http://nghttp2.org/httpbin/user-agent"
    let ret = parseJson(ss.dumpStream())
    check ret == %* { "user-agent": "ezcurl" }