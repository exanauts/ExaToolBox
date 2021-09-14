using Distributed
if length(ARGS) != 2
    println("Usage: julia --project feasible_contingencies.jl casefile nprocs")
    exit()
end
nprocs = parse(Int, ARGS[2])
addprocs(nprocs, exeflags="--project")
@everywhere begin
using PowerModels
using Ipopt

abstract type Contingency end
struct LineContingency <: Contingency end
struct GenContingency <: Contingency end

function solve(network, id)
    try
        # if id != 133
        #     result = run_ac_opf(network, optimizer_with_attributes(
        #         Ipopt.Optimizer,
        #         "print_level" => 0, "max_iter" => 200
        #         )
        #     )
        # else
            result = run_ac_opf(network, optimizer_with_attributes(
                Ipopt.Optimizer,
                "print_level" => 5, "max_iter" => 200
                )
            )
        # end
        if result["termination_status"] == LOCALLY_SOLVED
            return true
        else
            return false
        end
    catch e
        return false
    end
end

function solve_contingency(id::Int, network, ::LineContingency)
	cnetwork = deepcopy(network)
	cnetwork["branch"]["$id"]["br_status"] = 0
    return solve(cnetwork, id)
end

function solve_contingency(id::Int, network, ::GenContingency)
    cnetwork = deepcopy(network)
    cnetwork["gen"]["$id"]["gen_status"] = 0
    return solve(cnetwork, id)
end
end

case = ARGS[1]

network = PowerModels.parse_file(case; import_all=true)
PowerModels.export_matpower("export.m", network)

ngen = length(network["gen"])
nlines = length(network["branch"])

results_gens = pmap(x -> solve_contingency(x, network, GenContingency()), 1:ngen)
results_lines = pmap(x -> solve_contingency(x, network, LineContingency()), 1:nlines)

println("Found $(length(findall(results_gens))) feasible generator contingencies of a total of $ngen generators: $(findall(results_gens))")
println("Found $(length(findall(results_lines))) feasible line contingencies of a total of $nlines lines: $(findall(results_lines))")

