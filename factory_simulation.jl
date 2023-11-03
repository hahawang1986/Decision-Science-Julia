using DataStructures, StableRNGs, CSV, Distributions, DataFrames, DelimitedFiles,Dates,Printf 

# set up the RNG 
seed = 17 
rng = StableRNG(seed)

#=
this struct represents order(lawnmower) as an entuty in the queue
it is mutable so we can add the start_service field after it is initialised
=#
mutable struct Order
    id::Int64               # a unique id to be allocated upon arrival
    arrival_time::Float64   # the time of arrival (from start of simulation)
    start_service_time::Float64  # the time the constructrued process (from start of simulation)
    completion_time::Float64    # the time the constructrue be finished (from start of simulation)
    interrupted::Bool       # whether the order is interrupted or not
end

# generate a newly arrived order 
# where start_service and end_service are unknown, and interrupted is false
Order(id,arrival_time) = Order(id,arrival_time,Inf,Inf,false)

# Define the events
abstract type Event end 

struct Arrival <: Event
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end

mutable struct Departure <: Event # order was finished
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end

struct Breakdown <: Event # blade-fitting machine breaks
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end

struct Repair <: Event # blade-fitting machine has been repaired
    id::Int64         # a unique event id
    time::Float64     # the time of the event 
end

## define the system state
n_machine = 1

#=
this struct will represent the state of the system
it is mutable because we need to be able to change the state of the system
=#
# mutable struct SystemState
#     time::Float64                               # the system time (simulation time)
#     event_queue::PriorityQueue{Event,Float64}   # to keep track of future order arravals
#     order_queue::Queue{Order}                   # to keep track of waiting orders
#     n_orders::Int64                             # the number of orders
#     sum_waiting_time::Float64                   # to keep track of the total waiting time in the simulation
#     in_service::Union{Order,Nothing}            # to keep track of order in service
#     is_break::Bool                              # to keep track of machine status
#     n_interrupted::Int64                        # to keep track of the number of interruptions 
#     repair_time::Float64                        # to keep track of repair time for current machine status 
#     n_repaired::Int64                           # to keep track of the number of repairs 
#     sum_repair_time::Float64                    # to keep track of total repair time for the entity simulation
#     n_entities::Int64                           # the number of entities to have been served
#     n_events::Int64                             # tracks the number of events to have occur + queued
# end

mutable struct SystemState
    time::Float64                               # the system time (simulation time)
    event_queue::PriorityQueue{Event,Float64}   # to keep track of future events
    order_queue::Queue{Order}                   # to keep track of waiting orders
    departure_queue::Queue{Order}               # to keep track of completed orders or the order is pending due to machine broken
    in_service::Union{Order,Nothing}            # to keep track of order in service
    n_entities::Int64                           # the number of entities to have been served
    n_events::Int64                             # tracks the number of events to have occur + queued
    machine_status::Bool                        # False: breakdown, True: Available
end


# Initialize the system state
function State()
    start_time = 0.0
    init_event_queue = PriorityQueue{Event, Float64}()
    init_order_queue = Queue{Order}()
    init_departure_queue = Queue{Order}()  
    init_in_service = nothing
    init_n_entities = 0
    init_n_events = 0
    init_machine_status = true
    return SystemState(start_time,init_event_queue,init_order_queue,init_departure_queue, init_in_service,init_n_entities,init_n_events,init_machine_status)
end

# creating the random number generators
struct RandomNGs
    rng::StableRNGs.LehmerRNG
    interarrival_time::Function
    construction_time::Function
    interbreakdown_time::Function
    repair_time::Function
end

# a data structure for passing parameters
struct Parameters
    seed::Int
    mean_interarrival::Float64
    mean_construction_time::Float64
    mean_interbreakdown_time::Float64
    mean_repair_time::Float64
end

# using struct RandomNGs and Parameters
# all times are independent and 
# o the inter-arrival times between orders are independent and exponential 
# with a mean of one hour
# o the time to construct a lawnmower from parts is deterministic with a 
# time of 45 minutes
# o the time between breakdowns of the blade-fitting machine is 
# exponential with a mean of two days as measured from the last time it 
# was repaired
# o the time to fix the machine when it breaks is exponential with a mean of
# time three hours.
function RandomNGs(P::Parameters)
    rng = StableRNG(P.seed)
    interarrival_time() = rand(rng,Exponential(P.mean_interarrival))
    construction_time() = P.mean_construction_time
    interbreakdown_time() = rand(rng,Exponential(P.mean_interbreakdown_time))
    repair_time() = rand(rng,Exponential(P.mean_repair_time))
    return RandomNGs(rng,interarrival_time,construction_time,interbreakdown_time,repair_time)
end

# create a new system state and inject 
# an initial arrival at time 0.0 and 
# initial breakdown at time 150.0 minutes
function initialise(P::Parameters)
    R = RandomNGs(P) # create the RNGs
    system = State() # create the initial state structure
    # add an arrival at time 0.0
    t0 =0.0
    system.n_events +=1 # your system state should keep track of events
    enqueue!(system.event_queue,Arrival(0,t0),t0)
    # add a breakdown at time 150.0
    t1= 150.0
    system.n_events +=1
    enqueue!(system.event_queue,Breakdown(system.n_events,t1),t1)
    return(system,R)
end

function move_mower_to_server( system::SystemState,R::RandomNGs )
    # move the order from the wiating queue to in service and update it
    system.in_service = dequeue!(system.order_queue) # remove order from queue
    system.in_service.start_service_time = system.time  # start construction 'now'
    # create a departure event for this order
    system.n_events += 1
    next_departure_time = system.time + R.construction_time()
    next_departure = Departure(system.n_events,next_departure_time)
    enqueue!(system.event_queue,next_departure,next_departure_time)
end

## System update functions
#=
# update!(system,arrival::Arrival)
#
# Update the system when in response to an event.
# Input: 
#    + system: a System struct to be updated
#    + e:      an event
#    + R:      time generator
# Output: 
#    + the order which arrived or departed, machine break or repaired .. in response to the event
#
=#
function update!( system::SystemState, e::Event )
    throw( DomainError("invalid event type" ) )
end

# when arrival event arrived, it is put into waiting queue
# and build a new arrival event
function update!( system::SystemState,R::RandomNGs, event::Arrival )
        
    system.n_entities +=1
    arrival_time = system.time
    next_entity = Order(system.n_entities,arrival_time)
    enqueue!(system.order_queue,next_entity)
    
    system.n_events +=1
    next_arrival_time = system.time + R.interarrival_time()
    next_arrival = Arrival(system.n_events,next_arrival_time)
    enqueue!(system.event_queue,next_arrival,next_arrival_time)
   
    if system.machine_status == true && length(system.order_queue) > 0 && system.in_service == nothing
        move_mower_to_server(system,R)
    end

    return next_entity
end

# Departure Event
# change order's in_service status when departure event comes
# put the order into departure_queue
# decide whether an new order can be constructed.
function update!( system::SystemState,R::RandomNGs, event::Departure)
    system.in_service.completion_time = system.time
    enqueue!(system.departure_queue,system.in_service)
    system.in_service = nothing
    system.n_events +=1
 
    if system.machine_status == true && length(system.order_queue) > 0 && system.in_service == nothing
        move_mower_to_server(system,R)
    end
end

# Breakdown Event
# machine status change to be unavailable
# if order is in service,change the interrupted state
# if there is a departure event coming, adding the repair time to its time
# Trigger next repair event
function update!(system::SystemState,R::RandomNGs,event::Breakdown)
 
    system.machine_status = false
    repair_time = R.repair_time()

    if system.in_service != nothing
        system.in_service.interrupted = true
    end

    for (event,event_time) in system.event_queue
        if event_time >= system.time && typeof(event) <: Departure
            system.event_queue[event] += repair_time
            event.time = repair_time + event_time
        end
    end
    system.n_events +=1
    next_repair_time = system.time + repair_time
    next_repair = Repair(system.n_events,next_repair_time)
    enqueue!(system.event_queue,next_repair,next_repair_time)
end

# Repair Event
# machine status change to be available
# decide whether an order in the waiting queue can be constructed
# trigger new breakpoint event
function update!(system::SystemState,R::RandomNGs,event::Repair)
    system.machine_status = true
    system.n_events +=1
    next_breakdown_time = system.time + R.interbreakdown_time()
    next_breakdown = Breakdown(system.n_events,next_breakdown_time)
    enqueue!(system.event_queue,next_breakdown,next_breakdown_time)

    if system.machine_status == true && length(system.order_queue) > 0 && system.in_service == nothing
        move_mower_to_server(system,R)
    end
end

function run!(S::SystemState,R::RandomNGs,T::Float64,fid_state::IO,fid_entities::IO)
    
    current_date = Dates.now()
    formatted_date = Dates.format(current_date, "yyyy-MM-dd HH:MM:SS")
    # Print header information
    header_info = [
        "# file created by code in factory_simulation.jl",
        "# file created on $formatted_date",
        "# parameter:",
        "# seed = $seed",
        "# mean_interarrival = $mean_interarrival",
        "# mean_construction_time = $mean_construction_time",
        "# mean_interbreakdown_time = $mean_interbreakdown_time",
        "# mean_repair_time = $mean_repair_time",
        "# T = $T",
        "# time units = minutes",
        "time, event_id, event_type, length_event_list, length_queue, in_service, machine_status"
    ]
    println(fid_state, join(header_info, "\n"))
    
     # Print entity information
     entity_info = [
        "# file created by code in factory_simulation.jl",
        "# file created on $formatted_date",
        "# parameter:",
        "# seed = $seed",
        "# mean_interarrival = $mean_interarrival",
        "# mean_construction_time = $mean_construction_time",
        "# mean_interbreakdown_time = $mean_interbreakdown_time",
        "# mean_repair_time = $mean_repair_time",
        "# T = $T",
        "# time units = minutes",
        "id, arrival_time, start_service_time, completion_time, interrupted"
    ]
    println(fid_entities, join(entity_info, "\n"))

    while system.time < T
        event, time = dequeue_pair!(system.event_queue)
        system.time = time
        remaining_events = length([e for (e, _) in S.event_queue if e.time > S.time])
        remaining_entities = count(e.start_service_time == Inf for e in S.order_queue)
        if typeof(event) == Arrival
            event_info = "$(time),$(event.id),Arrival,$(remaining_events),$(remaining_entities),$(system.in_service === nothing ? 0 : 1),$(system.machine_status === true ? 0 : 1)"
            println(fid_state, event_info)  
            update!(system, R, event)
        elseif typeof(event) == Breakdown
            event_info = "$(time),$(event.id),Breakdown,$(remaining_events),$(remaining_entities),$(system.in_service === nothing ? 0 : 1),$(system.machine_status === true ? 0 : 1)"
            println(fid_state, event_info)  
            update!(system, R, event)
        elseif typeof(event) == Repair
            event_info = "$(time),$(event.id),Repair,$(remaining_events),$(remaining_entities),$(system.in_service === nothing ? 0 : 1),$(system.machine_status=== true ? 0 : 1)"
            println(fid_state, event_info)  
            update!(system, R, event)
        elseif typeof(event) == Departure
            event_info = "$(time),$(event.id),Departure,$(remaining_events),$(remaining_entities),$(system.in_service === nothing ? 0 : 1),$(system.machine_status === true ? 0 : 1)"
            println(fid_state, event_info)  
            update!(system, R, event)
        end
    end

    for entity in S.departure_queue
        if entity.completion_time != Inf
            entity_info = "$(entity.id),$(entity.arrival_time),$(entity.start_service_time),$(entity.completion_time),$(entity.interrupted== false ? 0 : 1)"
            println(fid_entities, entity_info)
        end
    end
    # final
    # Determine the final result
    result = S.machine_status ? 0 : 1
    return result
end

