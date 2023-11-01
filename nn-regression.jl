module load_nn
    using MLJ, DataFrames, Plots, CSV,MLJDecisionTreeInterface
    df = CSV.read("thermal-simulation/data/eplusout_v29102023.csv",DataFrame)
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

    y, X = unpack(df_filtered, ==(:x7); rng=123);

    train_y = y[1:trunc(Int,ceil(length(y)*0.85))]
    train_X = X[1:trunc(Int,ceil(length(y)*0.85)),:]
    test_y = y[trunc(Int,ceil(length(y)*0.85))+1:length(y)]
    test_X = X[trunc(Int,ceil(length(y)*0.85))+1:length(y),:]

    vcat(train_X,test_X)


    models(matching(X,y))

    doc("DecisionTreeRegressor",pkg="DecisionTree")

    modelType = @load DecisionTreeRegressor pkg = "DecisionTree" verbosity=0

    model = modelType()

    mach = machine(model, train_X, train_y) |> MLJ.fit!

    yhat = MLJ.predict(mach,vcat(train_X,test_X)) 

    export mach
    export train_y
    export train_X
    export test_y
    export test_X
    export yhat
end