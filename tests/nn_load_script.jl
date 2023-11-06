using MLJ, Flux, DataFrames, Plots, CSV, Serialization
import MLJFlux

# DATA DOCUMENTATION
# 01 Date/Time
# 02 Environment:Site Outdoor Air Drybulb Temperature [C](Hourly)
# 03 Environment:Site Outdoor Air Humidity Ratio [kgWater/kgDryAir](Hourly)
# 04 Environment:Site Outdoor Air Relative Humidity [%](Hourly)
# 05 Environment:Site Outdoor Air Barometric Pressure [Pa](Hourly)
# 06 Environment:Site Wind Speed [m/s](Hourly)
# 07 Environment:Liquid Precipitation Depth [m](Hourly)
# 08 ZONE ONE PEOPLE:People Occupant Count [](Hourly)
# 09 ZONE ONE PEOPLE:People Total Heating Rate [W](Hourly)
# 10 SPACE1-1 LIGHTS 1:Lights Total Heating Rate [W](Hourly)
# 11 ZONE ONE:Zone Windows Total Transmitted Solar Radiation Rate [W](Hourly)
# 12 ZONE ONE:Zone Mean Air Temperature [C](Hourly)
# 13 ZONE ONE:Zone Mean Air Humidity Ratio [kgWater/kgDryAir](Hourly)
# 14 ZONE ONE:Zone Air Relative Humidity [%](Hourly)
# 15 ZONE ONE PEOPLE:Zone Thermal Comfort Fanger Model PMV [](Hourly)
# 16 ZONE ONE PEOPLE:Zone Thermal Comfort Fanger Model PPD [%](Hourly)
# 17 ZONE ONE PEOPLE:Zone Thermal Comfort Pierce Model Standard Effective Temperature [C](Hourly)
# 18 ZONE ONE PEOPLE:Zone Thermal Comfort ASHRAE 55 Elevated Air Speed Cooling Effect [C](Hourly)
# 19 ZONE ONE PEOPLE:Zone Thermal Comfort ASHRAE 55 Elevated Air Speed Cooling Effect Adjusted PMV [](Hourly)
# 20 ZONE ONE PEOPLE:Zone Thermal Comfort ASHRAE 55 Elevated Air Speed Cooling Effect Adjusted PPD [](Hourly)
# 21 ZONE ONE PEOPLE:Zone Thermal Comfort ASHRAE 55 Ankle Draft PPD [](Hourly)
# 22 ZONE ONE:Zone Heat Index [C](Hourly)
# 23 ZONE ONE:Zone Humidity Index [](Hourly)
# 24 total_load


df = CSV.read("data/eplusout_v29102023.csv",DataFrame)


people_load = df[:,9]
light_load = df[:,10]
total_load = people_load + light_load
df[!,:total_load] = total_load
df_filtered = DataFrame(hcat(df[:,2],df[:,4],df[:,6],df[:,7],df[:,8],df[:,10],df[:,24]),:auto)

colunas = names(df)
colunas = names(df_filtered)

for i in 1:length(colunas)
    println(i," ",colunas[i])
end

y, X = unpack(df_filtered, ==(:x7); rng=123);
X = coerce(X, :RAD=>Continuous)
(X, Xtest), (y, ytest) = partition((X, y), 0.7, multi=true);

y = df_filtered[1:1075,7]
ytest = df_filtered[1076:end,7]
X = df_filtered[1:1075,1:6]
Xtest = DataFrame(df_filtered[1076:end,1:6])


builder = MLJFlux.@builder begin
    init=Flux.glorot_uniform(rng)
    Chain(
        Dense(n_in, 64, relu, init=init),
        Dense(64, 32, relu, init=init),
        Dense(32, n_out, init=init),
    )
end

NeuralNetworkRegressor = @load NeuralNetworkRegressor pkg=MLJFlux
model = NeuralNetworkRegressor(
    builder=builder,
    rng=123,
    epochs=25
)

pipe = Standardizer()

pipe = MLJ.TransformedTargetModel(model, transformer=Standardizer())

mach = machine(pipe, X, y)
fit!(mach, verbosity=2)

#mach25 = deserialize("model/mach_25epoch_1536dp.dat")

yhat = MLJ.predict(mach,vcat(X,Xtest))
plot([yhat[1:336],total_load[1:336]])

serialize("model/yhat_nn_25epochs.dat",yhat)
yhat2 = deserialize("model/yhat_nn_25epochs.dat")