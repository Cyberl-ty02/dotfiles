-- Forward an existing build graph; do not reinterpret Make/Ninja options.
function main(backend, ...)
    local allowed = {make = true, ninja = true}
    assert(allowed[backend], "unsupported build backend")
    local program = backend == "make" and "/usr/bin/gmake" or "/usr/bin/ninja"
    if backend == "make" and not os.isexec(program) then
        program = "/usr/bin/make"
    end
    local code = os.execv(program, {...}, {try = true})
    os.exit(code or 127)
end
