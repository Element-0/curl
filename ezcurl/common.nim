from strutils import cmpIgnoreStyle

template `=!=`*(a, b: string): bool = cmpIgnoreStyle(a, b) == 0