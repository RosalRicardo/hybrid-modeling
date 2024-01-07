using JuMP
using Ipopt
using Plots
using Serialization

HYBRID_ZNT = deserialize("ZNT_HYBRID.dat")

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


# Define the function to apply control action (replace with your actual actuation logic)
function apply_control(u,t)
    heat_transfer_coefficient = 5000
    zone_width = 15.24
    zone_length = 15.24
    zone_height = 4.25
    air_density = 1.225 
    heat_capacity = 1005
    thermal_capacitance = (zone_width*zone_length*zone_height)*air_density*heat_capacity
    ΔT = ((heat_transfer_coefficient*u)/thermal_capacitance)*(60*10)
    return HYBRID_ZNT[t] + ΔT
    # Add your actuation logic here, such as adjusting a valve, fan, or heater
end


function run_temperature_mpc(initial_temperature_val)
    
    model = Model(Ipopt.Optimizer)

    # Define constant parameters
    Δt = 0.1
    num_time_steps = 15
    max_valve_opening = 1
    initial_temperature = initial_temperature_val
    desired_temperature = 20

    # Define decision variables
    @variables model begin
        temperature[1:num_time_steps]
        valve_opening[1:num_time_steps]
    end

    # Add dynamics constraints (simple first-order thermal system)
    @constraint(model, [i=2:num_time_steps],
                temperature[i] == temperature[i-1] - system_dynamics(temperature[i-1],valve_opening[i - 1],i))

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

temp, valve=run_temperature_mpc(HYBRID_ZNT[1])
plot(valve)
plot(temp)

#============================================================#
# ------------ SIMULATION OF THE MPC CONTROLLER -------------#
#============================================================#

using Plots
gr()


# Simulation parameters
num_time_steps = 1000
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
    append!(temperature_history,temperature_plan)
    append!(valve_opening_history,valve_opening_plan)

    # Apply the planned valve opening and simulate one step in time
    valve_opening = valve_opening_plan[1]
    q = q[end] - system_dynamics(q[end],valve_opening,i)
end

# Plot results
plot(1:num_time_steps, temperature_history, label="Temperature", xlabel="Time Step", ylabel="Temperature", linewidth=2)
plot(1:num_time_steps, valve_opening_history, label="Valve Opening", xlabel="Time Step", ylabel="Valve Opening", linewidth=2, linestyle=:dash)

plot(temperature_history[1:1000])