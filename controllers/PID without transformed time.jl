using Serialization, Plots

setpoint = 22
process_range = 30
coil_heat_transfer_coefficient = 650
coil_area = 0.35
chilled_water_temperature = 7 # C
heat_transfer_coefficient = 5000 # W
proportional_coefficient = 14.58
integral_coefficient = 14.58
flow = 3.202 #m3/h
plant_COP = 6

# parametros PID de acordo com Zigler-Nichols
# Kp = 0.6 * Kc
# Ki = 2 * Kp / Pc

# Oscillation Points
# Kc = 24.3 
# Pc = 2

# Kp = 14.58
# Kp = 14.58

HYBRID_ZNT = deserialize("ZNT_HYBRID.dat")

# transform in seconds
function tranform_time(ts)
    ZNT_10m = []
    for h in 1:length(ts)
        for m in 1:6
            push!(ZNT_10m,HYBRID_ZNT[h])
        end
    end
    return ZNT_10m
end

temperatura = tranform_time(HYBRID_ZNT)
temperatura = HYBRID_ZNT
Plots.plot(temperatura[1:1000])

function thermal_capacitance(zone_width,zone_length,zone_height,air_density=1.225,heat_capacity=1005)
    thermal_capacitance = (zone_width*zone_length*zone_height)*air_density*heat_capacity
    return thermal_capacitance
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

ZNT_10m = tranform_time(HYBRID_ZNT)

thermalCapacitance = thermal_capacitance(15.24,15.24,4.25)

error = ZNT_10m[1] - setpoint
control_signal = ((error*proportional_coefficient)+sum(error)/integral_coefficient)/process_range

ΔT = ((heat_transfer_coefficient*control_signal)/thermalCapacitance)*(60*10)

function controller(actual_temperature, setpoint,error_acc)
    error = actual_temperature - setpoint
    #error < 0 ? error = 0 : error = error
    thermalCapacitance = thermal_capacitance(15.24,15.24,4.25)
    control_signal = ((error*proportional_coefficient)+sum(error_acc)/integral_coefficient)/process_range
    ΔT = ((heat_transfer_coefficient*control_signal)/thermalCapacitance)*(60*10)
    return [actual_temperature - ΔT,control_signal,error]
end

controlled_temperature = []
control_signal = []
error = []
setpoint_series = ones(9072).*22

controller(HYBRID_ZNT[1],22)



delta_T = deltaT(HYBRID_ZNT)
for i in 1:length(HYBRID_ZNT)
    if i == 1
        push!(controlled_temperature,controller(HYBRID_ZNT[i],22)[1])
        _control_signal = controller(HYBRID_ZNT[i],22)[2]
        if _control_signal >= 1
            push!(control_signal,1)
        elseif _control_signal <= 0
            push!(control_signal,1)
        else
            push!(control_signal,controller(HYBRID_ZNT[i],22)[2])
        end
        push!(error,controller(HYBRID_ZNT[i],22)[3])
    else
        push!(controlled_temperature,controller((controlled_temperature[end])+delta_T[i],22,error)[1])
        _control_signal = control_signal[end]+controller((controlled_temperature[end])+delta_T[i],22,error)[2]
        if _control_signal >= 1
            push!(control_signal,1)
        elseif _control_signal <= 0
            push!(control_signal,1)
        else
            push!(control_signal,control_signal[end]+controller((controlled_temperature[end])+delta_T[i],22,error)[2])
        end
        push!(error,controller((controlled_temperature[end])+delta_T[i],22,error)[3])
    end
end

volume = control_signal.*(flow/6)

vacc =[volume[1]]
for i in 1:length(volume)-1
    push!(vacc,vacc[end]+volume[i+1])
end

plot1 = Plots.plot([controlled_temperature[1:432],ZNT_10m[1:432],setpoint_series[1:432]])
plot2 = Plots.plot(control_signal[1:432])
plot3 = Plots.plot(vacc[1:432])
plot4 = Plots.plot(error[1:432])
Plots.plot(plot1,plot2,plot3,plot4,layout=(4,1),size=(800,1200))

final_volume = vacc[50]
energy_consumption = vacc[50]*(3.6/plant_COP)

plot2 = Plots.plot(control_signal[1:50])
plot2 = Plots.plot(controlled_temperature[1:50])

Plots.plot(
    plot(1:50, [HYBRID_ZNT[1:50], controlled_temperature[1:50],setpoint_series[1:50]], label=["Uncontrolled" "Controlled" "Setpoint"], xlabel="Time", ylabel="Temperature", color=[:blue :green :black], linewidth=1,title="comparison between controlled and uncontrolled temperature (a)"),
    plot(1:50, control_signal[1:50], label="Control Action", xlabel="Time", ylabel="Valve Position", color=:red, linewidth=1,title="control output - cooling valve position (b)"),
    plot(1:50, vacc[1:50], label="Volume", xlabel="Time", ylabel="Water Volume", color=:blue, linewidth=1,title="max water consumption: 21.02 m³ (c)"),
    layout=(3, 1), legend=true,size=(800,600)
)