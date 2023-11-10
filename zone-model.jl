using  CairoMakie,DifferentialEquations, ModelingToolkit, Plots, GlobalSensitivity, Statistics, DataFrames, CSV, MLJ, Serialization
import MLJFlux
#include("./modules/trained_load.jl")


#mach = deserialize("model/mach_25epoch_1536dp.dat")
yhat = deserialize("model/yhat_nn_25epochs.dat")[25:end]


# variables

# Cz  - Overall thermal capacitance of the zone - 47.1 kJ/C
# Tz  - Zone Temperature - C
# Fsa - volume flow rate of supply fan - 0.192 m3/s
# ρa  - density of air - 1.25 kg/m3 
# Cpa - specific heat of supply air - 1.005 kJ/kgC
# Tsa - temperature of supply air - C
# Uw1 - overall heat transfer coefficient (East and west walls) - 2 w/m2C
# Uw2 - overall heat transfer coefficient (North and South walls) - 2 w/m2C
# Ur  - overall heat transfer coefficient (roof) - 1 w/m2C
# Aw1 - Area (East and West walls) - m2
# Aw2 - Area (North and South walls) - m2 
# Ar  - Area (Roof) - m2
# Tw1 - temperature (East and West walls) - C
# Tw2 - temperature (North and South walls) - C
# Tr  - temperature (Roof) - C
# q   - heat gain for occupants and lights - W
# wall X - 15.24 m
# wall Y - 4.572 m
# area - 69.68 m2

## READ RAW DATA

df = CSV.read("data/eplusout_v29102023.csv",DataFrame)

people_load = df[25:end,9]
light_load = df[25:end,10]
total_load = people_load + light_load
OAT = df[25:end,2]
ZNT = df[25:end,12]



@variables t Tz(t)=ZNT[1] Tw1(t)=OAT[1] Tw2(t)=OAT[1] Tr(t)=OAT[1] Wz(t)=0.8

#parameters Cz=47.1e3 Fsa=0.192*3600  ρa=1.25 Cpa=1.005 Tsa=16 Uw1=2 Uw2=2 Ur=1 Aw1=9 Aw2=12 Ar=9 q=3000 To=21 Cw1=70 Cw2=60 Cr=80 Vz=36 Ws=0.02744 P=0.08
@parameters Cz=4.5e3 Fsa=0  ρa=1.25 Cpa=1.005 Tsa=16 Uw1=0.2 Uw2=0.2 Ur=1 Aw1=69.68 Aw2=69.68 Ar=232.25 q=3000 To=OAT[1] Cw1=70 Cw2=60 Cr=70 Vz=36 Ws=0.02744 P=0.08

D = Differential(t)

eqs = [D(Tz) ~ (Fsa*ρa*Cpa*(Tsa-Tz)+2*Uw1*Aw1*(Tw1-Tz)+Ur*Ar*(Tr-Tz)+2*Uw2*Aw2*(Tw2-Tz)+q)/Cz
        D(Tw1) ~ (Uw1*Aw1*(Tz-Tw1)+Uw1*Aw1*(To-Tw1))/Cw1
        D(Tw2) ~ (Uw2*Aw2*(Tz-Tw2)+Uw1*Aw1*(To-Tw2))/Cw2
        D(Tr) ~ (Ur*Ar*(Tz-Tr)+Ur*Ar*(To-Tr))/Cr
        D(Wz) ~ (Fsa*(Ws-Wz)+(P/ρa))/Vz]

eqs2 = [D(Tz) ~ (Fsa*ρa*Cpa*(Tsa-Tz)+Uw1*Aw1*(To-Tz)+q)/Cz
        D(Tw1) ~ (Uw1*Aw1*(Tz-Tw1)+Uw1*Aw1*(To-Tw1))/Cw1
        D(Tw2) ~ (Uw2*Aw2*(Tz-Tw2)+Uw1*Aw1*(To-Tw2))/Cw2
        D(Tr) ~ (Ur*Ar*(Tz-Tr)+Ur*Ar*(To-Tr))/Cr
        D(Wz) ~ (Fsa*(Ws-Wz)+(P/ρa))/Vz]        

@named sys = ODESystem(eqs,t)

simpsys = structural_simplify(sys)


tspan = (1.0,1512.0)

ev_times = collect(1.0:1.0:1512.0)

condition(u,t,integrator) = t ∈ ev_times
#affect!(integrator) = integrator.u[1] += 5*rand(); print(integrator.p[15])

function affect!(integrator)

    integrator.p[3] = yhat[trunc(Int,integrator.t)]
    integrator.p[13] = OAT[trunc(Int,integrator.t)]

    #push!(energy2,integrator.p[3])
    println(integrator.p)
end

function affect2!(integrator)

    integrator.p[3] = 1000
    integrator.p[13] = OAT[trunc(Int,integrator.t)]

    #push!(energy2,integrator.p[3])
    println(integrator.p)
end

cb = DiscreteCallback(condition,affect!)

prob = ODEProblem(simpsys,[],tspan,callback=cb,tstops=ev_times)

sol = solve(prob)

ODEZNT = []
ODERoofT = []
for i in 1:length(ZNT)
    push!(ODEZNT,sol(i)[1])
    push!(ODERoofT,sol(i)[2])
end

serialize("ZNT_HYBRID.dat",ODEZNT)
#serialize("ODEZNT_DETERMINISTIC.dat",ODEZNT)
#ZNT_HYBRID = deserialize("ODEZNT.dat")
ZNT_DETERMINISTIC = deserialize("ODEZNT_DETERMINISTIC.dat")


plot1 = Plots.plot([ODEZNT[1:336],ZNT[1:336]])
plot2 = Plots.plot([ZNT_DETERMINISTIC[1:336],ZNT[1:336]])
plot3 = Plots.plot([total_load[1:336],yhat[1:336]])
plot4 = Plots.plot([OAT[1:336]])
plot_grid = Plots.plot(plot1,plot2,plot3,plot4,layout=(4,1),size=(1024,1024))
Plots.plot([ODERoofT[1:336],OAT[1:336]])


Plots.plot(sol)


Plots.plot([people_load[25:121],light_load[25:121]])

#error calculation
function calculate_errors(actual, predicted)
    if length(actual) != length(predicted)
        throw(ArgumentError("Input vectors must have the same length."))
    end
    
    n = length(actual)
    
    # Calculate MSE
    mse = sum((actual .- predicted).^2) / n
    
    # Calculate MAE
    mae = sum(abs.(actual .- predicted)) / n
    
    return mse, mae
end

hybrid_errors = calculate_errors(ODEZNT,ZNT)
deterministics_errors = calculate_errors(ZNT_DETERMINISTIC,ZNT)

1-hybrid_errors[1]/deterministics_errors[1]

1-hybrid_errors[2]/deterministics_errors[2]



