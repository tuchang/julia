
tmp = tempname()
if haskey(Base.loaded_modules, Base.PkgId(Base.UUID("3fa0cd96-eef1-5676-8a61-b3b8758bbffb"), "REPL"))
    # Record precompile statements when starting a julia session with a repl
    run(pipeline(`$(Base.julia_cmd()) --trace-compile=yes -e '
        @async while true
            sleep(0.01)
            isdefined(Base, :active_repl) && exit(0)
        end' -i`; stderr = tmp))
    # Replay a REPL script
    repl_replay = joinpath(@__DIR__, "precompile_replay.jl")
    run(pipeline(`$(Base.julia_cmd()) --trace-compile=yes $repl_replay`; stderr=tmp, append=true))
else
    # No REPL, just record the startup
    run(pipeline(`$(Base.julia_cmd()) --trace-compile=yes -e 'exit(0)'`; stderr=tmp))
end

# Replace the fake terminal with the real terminal and filter out everything we compiled in Main
precompiles = readlines(tmp)
new_precompiles = String[]
for line in precompiles
    line = replace(line, "FakeTerminals.FakeTerminal" => "REPL.Terminals.TTYTerminal")
    (occursin(r"Main.", line) || occursin(r"FakeTerminals.", line)) && continue
    push!(new_precompiles, line)
end
write(tmp, join(new_precompiles, '\n'))

# Only write the precompile in case it is different

include("fixup_precompile.jl")
precompile_local = joinpath(@__DIR__, "..", "base/precompile_local.jl")
tmp2 = tempname()
isfile(precompile_local) && cp(precompile_local, tmp2)
fixup_precompile(tmp; merge=true, keep_anonymous=true, header=false, output=tmp2)
# Only update timestamp if different
if !isfile(precompile_local) || (isfile(precompile_local) && (read(tmp2, String) != read(precompile_local, String)))
    println("Updatingf...")
    mv(tmp2, precompile_local; force=true)
end
rm(tmp)