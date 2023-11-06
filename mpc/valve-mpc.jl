using JuMP, Serialization, Plots
using Ipopt

x = deserialize("data/ODEZNT_1512h.dat")
setpoint = 22.0

# Define the MPC parameters
N = 200  # Prediction horizon
Δt = 1  # Time step
u_max = 100
u_min = 1

# Define system dynamics (you will need to replace this with your actual model)
function cooling_coil_dynamics(T_zone, T_outside, u, dt, C, U)
    # T_zone: Zone temperature
    # T_outside: Outside temperature
    # u: Cooling control input (e.g., valve opening)
    # dt: Time step
    # C: Thermal capacitance of the zone
    # U: Overall heat transfer coefficient
    
    # Calculate the heat transfer rate
    Q = U * (T_outside - T_zone)
    
    # Calculate the change in energy of the zone
    dE = Q * dt
    
    # Update the zone temperature using the thermal capacitance
    T_zone_new = T_zone + dE / C
    
    # Apply the cooling control input
    T_zone_new -= u  # Assuming u represents the cooling effect
    
    return T_zone_new
end


# Define the model
m = Model(optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 0))

# Define decision variables
@variables m begin
    u_min <= u[1:N] <= u_max  # Cooling control valve
end

# Define state and output variables (you will need to replace these with your actual variables)
@variables m begin
    x[1:N+1]  # Zone temperature
end

# Define constraints (you will need to replace these with your actual constraints)
@constraints m  begin
    u_min .<= u[1:N] .<= u_max
end

# Define the objective function (you will need to replace this with your actual cost function)
@objective m Min sum((x[1:N] .- setpoint).^2)

# Set initial conditions and setpoints
#Ipopt.setvalue.(x, initial_conditions)  # Set initial zone temperature
setpoint = 22.0  # Setpoint for zone temperature

# Define the optimization problem and solve
optimize!(m)

# Retrieve the optimal control inputs
u_optimal = value.(u)
Plots.plot(u_optimal)

# Apply the first optimal control input to the system
# You will need to replace this with your actual control action
apply_control(u_optimal[1])
