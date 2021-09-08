using PowerModels
using Ipopt
using Distributed

abstract type Contingency end
struct LineContingency <: Contingency end
struct GenContingency <: Contingency end


function solve_contingency(id::Int, network, ::LineContingency)
	cnetwork = deepcopy(network)
	cnetwork["branch"]["$id"]["br_status"] = 0
	result = run_ac_opf(cnetwork, optimizer_with_attributes(
        Ipopt.Optimizer,
        "print_level" => 0
        )
    )
    if result["termination_status"] == LOCALLY_SOLVED
        return true
    else
        return false
    end
end

function solve_contingency(id::Int, network, ::GenContingency)
	cnetwork = deepcopy(network)
	cnetwork["gen"]["$id"]["gen_status"] = 0
	result = run_ac_opf(cnetwork, optimizer_with_attributes(
        Ipopt.Optimizer,
        "print_level" => 0
        )
    )
    if result["termination_status"] == LOCALLY_SOLVED
        return true
    else
        return false
    end
end

if length(ARGS) != 1
    println("Usage: julia --project feasible_contingencies.jl casefile")
    exit()
end

case = ARGS[1]

network = PowerModels.parse_file(case; import_all=true)

ngen = length(network["gen"])
nlines = length(network["branch"])

results_gens = pmap(x -> solve_contingency(x, network, GenContingency()), 1:ngen)
results_lines = pmap(x -> solve_contingency(x, network, LineContingency()), 1:nlines)

println("Found $(length(findall(results_gens))) feasible generator contingencies of a total of $ngen generators: $(findall(results_gens))")
println("Found $(length(findall(results_lines))) feasible line contingencies of a total of $nlines lines: $(findall(results_lines))")

