using DataStructures, Distributions, StableRNGs, Dates, Printf

# load "factory_simulation.jl"
include("factory_simulation.jl")


# set the specific Parameters 
seed = 1
mean_interarrival = 60.0
mean_construction_time = 25.0
mean_interbreakdown_time = 2880.0
mean_repair_time = 180.0
P = Parameters(seed, mean_interarrival, mean_construction_time, mean_interbreakdown_time, mean_repair_time)

#set conditions for run
(system,R) = initialise(P)

# build two CSVs to store the data
fid_state = open("state.csv", "w")
fid_entities = open("entities.csv", "w")
# simulation time
T = 1_000.0
run!(system, R, T,fid_state,fid_entities )

close(fid_state)
close(fid_entities)