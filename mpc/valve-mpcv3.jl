using JuMP
using Ipopt
using Plots

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
    return HYBRID_ZNT[t] - ΔT
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

model = Model(Ipopt.Optimizer)

# Define constant parameters
Δt = 0.1
num_time_steps = 20
max_valve_opening = 1.0
initial_temperature = HYBRID_ZNT[1]
desired_temperature = 20.0

# Define decision variables
@variables model begin
    temperature[1:num_time_steps]
    valve_opening[1:num_time_steps]
end

# Add dynamics constraints (simple first-order thermal system)
@constraint(model, [i=2:num_time_steps],
            temperature[i] == system_dynamics(temperature[i-1],valve_opening[i - 1],i))

# Constraint to limit valve opening
@constraint(model, valve_opening .>= 0)
@constraint(model, valve_opening .<= max_valve_opening)

# Cost function: minimize deviation from the desired temperature and valve opening
@objective(model, Min, 
    sum((temperature .- desired_temperature).^2)+ sum(valve_opening.^2))

# Initial conditions
@constraint(model, temperature[1] == initial_temperature)
@constraint(model, valve_opening[1] == 0)

# Solve the MPC problem
optimize!(model)

# Access the optimal temperature trajectory and valve opening
optimal_temperature = value.(temperature)
optimal_valve_opening = value.(valve_opening)

plot(optimal_temperature)
plot(optimal_valve_opening)

println("Optimal Temperature Trajectory: ", optimal_temperature)
println("Optimal Valve Opening: ", optimal_valve_opening)



function run_temperature_mpc(initial_position, initial_velocity)
    
    model = Model(Ipopt.Optimizer)

    # Define constant parameters
    Δt = 0.1
    num_time_steps = 1
    max_valve_opening = 1
    initial_temperature = HYBRID_ZNT[1]
    desired_temperature = 20.0

    # Define decision variables
    @variables model begin
        temperature[1:num_time_steps]
        valve_opening[1:num_time_steps]
    end

    # Add dynamics constraints (simple first-order thermal system)
    @constraint(model, [i=2:num_time_steps],
                temperature[i] == system_dynamics(temperature[i-1],valve_opening[i - 1],i))

    # Constraint to limit valve opening
    @constraint(model, valve_opening .>= 0)
    @constraint(model, valve_opening .<= max_valve_opening)

    # Cost function: minimize deviation from the desired temperature and valve opening
    @objective(model, Min, 
        sum((temperature .- desired_temperature).^2)+ sum(valve_opening.^2))

    # Initial conditions
    @constraint(model, temperature[1] == initial_temperature)
    @constraint(model, valve_opening[1] == 0)

    # Solve the MPC problem
    optimize!(model)

    return value.(temperature), value.(valve_opening)
end

# Initialize initial conditions
initial_temperature = HYBRID_ZNT[1]
initial_valve_opening = 0.0
q = [initial_temperature]
v = [initial_valve_opening]

# Simulation parameters
num_time_steps = 200
Δt = 0.5
desired_temperature = 20.0

# Arrays to store results
temperature_history = zeros(num_time_steps)
valve_opening_history = zeros(num_time_steps)

# Simulation loop
for i in 1:num_time_steps
    # Run the MPC control optimization
    temperature_plan, valve_opening_plan = run_temperature_mpc(q, v)

    # Store results
    temperature_history[i] = q[end]
    valve_opening_history[i] = valve_opening_plan[1]

    # Apply the planned valve opening and simulate one step in time
    valve_opening = valve_opening_plan[1]
    q = [q[end] + Δt * (0.1 * (desired_temperature - q[end]) - valve_opening)]
end

# Plot results
plot(1:num_time_steps, temperature_history, label="Temperature", xlabel="Time Step", ylabel="Temperature", linewidth=2)
plot(1:num_time_steps, valve_opening_history, label="Valve Opening", xlabel="Time Step", ylabel="Valve Opening", linewidth=2, linestyle=:dash)

