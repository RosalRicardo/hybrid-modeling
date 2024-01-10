using JuMP
using Ipopt
using Plots
using Serialization

HYBRID_ZNT = deserialize("ZNT_HYBRID.dat")
coil_heat_transfer_coefficient = 650
coil_area = 0.35
chilled_water_temperature = 5 # C
heat_transfer_coefficient = 5000 # W
flow = 3.202 #m3/h
plant_COP = 6


# Define the system dynamics function (replace with your actual model)
function system_dynamics(x, u, t)
    heat_transfer_coefficient = 5000
    zone_width = 15.24
    zone_length = 15.24
    zone_height = 4.25
    air_density = 1.225 
    heat_capacity = 1005
    thermal_capacitance = (zone_width*zone_length*zone_height)*air_density*heat_capacity
    ΔT = ((heat_transfer_coefficient*u)/thermal_capacitance)*(60*10)
    return ΔT
end

function deltaT(znt)
    deltaT = []
    for i in 1:length(znt)
        if i == 1 
            push!(deltaT,0)
        else
            push!(deltaT,znt[i]-znt[i-1])
        end
    end
    return deltaT
end

delta_T = deltaT(HYBRID_ZNT)

plot(delta_T[1:200])

function run_temperature_mpc(initial_temperature_val)
    
    model = Model(Ipopt.Optimizer)

    # Define constant parameters
    Δt = 0.1
    num_time_steps = 50
    max_valve_opening = 1
    initial_temperature = initial_temperature_val
    desired_temperature = 22

    # Define decision variables
    @variables model begin
        temperature[1:num_time_steps]
        valve_opening[1:num_time_steps]
    end

    # Add dynamics constraints (simple first-order thermal system)
    @constraint(model, [i=2:num_time_steps],
                temperature[i] == temperature[i-1] - system_dynamics(temperature[i-1],valve_opening[i - 1],i)+delta_T[i])

    # Constraint to limit valve opening
    @constraint(model, valve_opening .>= 0)
    @constraint(model, valve_opening .<= max_valve_opening)

    # Cost function: minimize deviation from the desired temperature and valve opening
    @objective(model, Min, 
        sum((temperature .- desired_temperature).^2))

    # Initial conditions
    @constraint(model, temperature[1] == initial_temperature)
    @constraint(model, valve_opening[1] == 0)

    # Solve the MPC problem
    optimize!(model)

    return value.(temperature), value.(valve_opening)
end

temp, valve=run_temperature_mpc(ZNT10m[1])
plot(valve)
plot(temp)
volume = valve.*(flow/6)

vacc =[volume[1]]
for i in 1:length(volume)-1
    push!(vacc,vacc[end]+volume[i+1])
end

setpoint_series = ones(50).*22

plot(
    plot(1:50, [HYBRID_ZNT[1:50], temp,setpoint_series], label=["Uncontrolled" "Controlled"], xlabel="Time", ylabel="Temperature", color=[:blue :green :black], linewidth=1,title="comparison between controlled and uncontrolled temperature"),
    plot(1:50, valve, label="Control Action", xlabel="Time", ylabel="Valve Position", color=:red, linewidth=1,title="control output - cooling valve position"),
    plot(1:50, vacc, label="Volume", xlabel="Time", ylabel="Water Volume", color=:blue, linewidth=1,title="max water consumption: 2.96 m^3"),
    layout=(3, 1), legend=true,size=(800,600)
)

volume = valve.*(flow/6)


final_volume = vacc[50]
energy_consumption = vacc[20]*(3.6/plant_COP)

#============================================================#
# ------------ SIMULATION OF THE MPC CONTROLLER -------------#
#============================================================#

using Plots
gr()


# Simulation parameters
num_time_steps = 200
Δt = 0.1
desired_temperature = 20.0

# Initialize initial conditions
initial_temperature = HYBRID_ZNT[1]
initial_valve_opening = 0.0
q = [initial_temperature]
v = [initial_valve_opening]

# Arrays to store results
temperature_history = zeros(num_time_steps)
valve_opening_history = zeros(num_time_steps)

# Simulation loop
for i in 1:num_time_steps
    # Run the MPC control optimization
    temperature_plan, valve_opening_plan = run_temperature_mpc(q[end])

    # Store results
    temperature_history[i] = q[end]
    valve_opening_history[i] = valve_opening_plan[1]

    # Apply the planned valve opening and simulate one step in time
    valve_opening = valve_opening_plan[1]
    q = [q[end] - system_dynamics(q[end],valve_opening,i)+ delta_T[i]]
end

# Plot results
plot(1:num_time_steps, temperature_history, label="Temperature", xlabel="Time Step", ylabel="Temperature", linewidth=2)
plot(1:num_time_steps, valve_opening_history, label="Valve Opening", xlabel="Time Step", ylabel="Valve Opening", linewidth=2, linestyle=:dash)

volume = valve.*(flow/6)

vacc =[volume[1]]
for i in 1:length(volume)-1
    push!(vacc,vacc[end]+volume[i+1])
end

final_volume = vacc[50]
energy_consumption = vacc[20]*(3.6/plant_COP)


plot(temperature_history)