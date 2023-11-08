using Serialization, Plots

setpoint = 22.0
process_range = 20
coil_heat_transfer_coefficient = 650
coil_area = 0.35
chilled_water_temperature = 7
heat_transfer_coefficient = 914
proportional_coefficient = 0.5
integral_coefficient = 700


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


ZNT_10m = tranform_time(HYBRID_ZNT)

thermalCapacitance = thermal_capacitance(15.24,15.24,4.25)

error = ZNT_10m[1] - setpoint
control_signal = ((error*proportional_coefficient)+sum(error)/integral_coefficiente)/process_range

ΔT = ((heat_transfer_coefficient*control_signal)/thermalCapacitance)*(60*10)

function controller(actual_temperature, setpoint)
    error = actual_temperature - setpoint
    thermalCapacitance = thermal_capacitance(15.24,15.24,4.25)
    control_signal = ((error*proportional_coefficient)+sum(error)/integral_coefficiente)/process_range
    ΔT = ((heat_transfer_coefficient*control_signal)/thermalCapacitance)*(60*10)
    return actual_temperature - ΔT
end

controlled_temperature = []
for i in 1:length(ZNT_10m)
    if i == 1
        push!(controlled_temperature,controller(ZNT_10m[i],22))
    else
        push!(controlled_temperature,controller((controlled_temperature[end]+0.1*ZNT_10m[i])/2,22))
    end
end

Plots.plot([controlled_temperature[1:80],ZNT_10m[1:80]])



