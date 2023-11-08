using Serialization, Plots

setpoint = 22.0
process_range = 20
coil_heat_transfer_coefficient = 650
coil_area = 0.35
chilled_water_temperature = 7
heat_transfer_coefficient = 914
proportional_coefficient = 0.75
integral_coefficient = 700
flow = 3.202 #m3/h
plant_COP = 6


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

function controller(actual_temperature, setpoint)
    error = actual_temperature - setpoint
    error < 0 ? error = 0 : error = error
    thermalCapacitance = thermal_capacitance(15.24,15.24,4.25)
    control_signal = ((error*proportional_coefficient)+sum(error)/integral_coefficient)/process_range
    ΔT = ((heat_transfer_coefficient*control_signal)/thermalCapacitance)*(60*10)
    return [actual_temperature - ΔT,control_signal]
end

controlled_temperature = []
control_signal = []


delta_T = deltaT(ZNT_10m)
for i in 1:length(ZNT_10m)
    if i == 1
        push!(controlled_temperature,controller(ZNT_10m[i],22)[1])
        push!(control_signal,controller(ZNT_10m[i],22)[2])
    else
        push!(controlled_temperature,controller((controlled_temperature[end])+delta_T[i],22)[1])
        push!(control_signal,controller(ZNT_10m[i],22)[2])
    end
end

volume = control_signal.*(flow/6)

vacc =[volume[1]]
for i in 1:length(volume)-1
    push!(vacc,vacc[end]+volume[i+1])
end

plot1 = Plots.plot([controlled_temperature[1:1000],ZNT_10m[1:1000]])
plot2 = Plots.plot(control_signal)
plot3 = Plots.plot(vacc)
plot(plot1,plot2,plot3,layout=(3,1),size=(640,800))

final_volume = vacc[end]
energy_consumption = vacc[end]*(3.6/plant_COP)








