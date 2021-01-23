# Package

version       = "0.1.0"
author        = "CodeHz"
description   = "Curl binding"
license       = "LGPL-3.0"
srcDir        = "."
skipDirs      = @["tests"]


# Dependencies

requires "nim >= 1.4.2"
requires "libcurl >= 1.0.0"
requires "ezutils"

const link = "https://github.com/Element-0/Dependencies/releases/download/curl-curl-7_74_0/libcurl.dll"

task prepare, "Prepare libcurl.dll":
  if not fileExists "libcurl.dll":
    exec "curl -Lo libcurl.dll " & link

before test:
  prepareTask()

before install:
  prepareTask()