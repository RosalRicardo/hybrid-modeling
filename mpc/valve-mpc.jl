using JuMP, Plots
using Ipopt

function mpc_controller(N, initial_conditions, u_min, u_max, setpoint)
    # Define MPC parameters
    N = 10  # Prediction horizon
    Δt = 1  # Time step
    setpoint = 22.0
    u_min = 0
    u_max = 1

    # Define system dynamics (replace with your actual model)
    function system_dynamics(x, u)
        heat_transfer_coefficient = 5000
        zone_width = 15.24
        zone_length = 15.24
        zone_height = 4.25
        air_density = 1.225 
        heat_capacity = 1005
        thermal_capacitance = (zone_width*zone_length*zone_height)*air_density*heat_capacity
        ΔT = ((heat_transfer_coefficient*u)/thermal_capacitance)*(60*10)
        return x + ΔT
    end

    # Create a JuMP model
    m = Model(optimizer_with_attributes(Ipopt.Optimizer, "print_level" => 1))

    # Define decision variables
    @variables m begin
        u_min <= u[1:N] <= u_max  # Cooling control input
    end

    # Define state variables
    @variables m begin
        x[1:N+1]  # Zone temperature
    end

    # Define constraints (replace with your actual constraints)
    @constraints m begin
        u_min .<= u .<= u_max
    end

    

    for i in 1:N
        @constraint(m,x[i+1] == system_dynamics(x[i], u[i]))
    end

    # Define the objective function (replace with your actual cost function)
    #@objective m Min sum((x[1:N] - setpoint).^2)
    @objective(m,Min,sum((x[1:N] .- setpoint).^2))

    # Set initial conditions and setpoints
    #setvalue.(x, initial_conditions)  # Set initial zone temperature
    setpoint = 22.0  # Setpoint for zone temperature

    # Solve the optimization problem
    optimize!(m)

    # Retrieve the optimal control inputs
    u_optimal = value.(u)

    # Apply the first optimal control input to the system
    # (replace this with your actual control action)
    apply_control(u_optimal[1])
    return [m,u_optimal]
end

function apply_control(u)
    # Your control action implementation here
    println("Applying control input:", u)
end

# Replace the following with your actual initial conditions and constraints
initial_conditions = [31.21 for _ in 1:11]  # Initial zone temperature
u_min = 0.0  # Minimum control input
u_max = 10.0  # Maximum control input


# Run the MPC controller simulation
N = 10  # Prediction horizon
x_history, u_history = mpc_controller(N, initial_conditions, u_min, u_max, setpoint)

# Plotting
time_steps = 1:24*60
plot(time_steps, x_history[1, :], label="Zone Temperature", xlabel="Time (minutes)", ylabel="Temperature (°C)", linewidth=2)
plot!(time_steps[1:end-N+1], u_history[1, :], label="Control Input", linewidth=2, linestyle=:dash)