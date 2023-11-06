using MLJ, Flux, Plots
import MLJFlux

data = OpenML.load(531); ## Loads from https://www.openml.org/d/531
y, X = unpack(data, ==(:MEDV), !=(:CHAS); rng=123);

scitype(y)
schema(X)

X = coerce(X, :RAD=>Continuous)

(X, Xtest), (y, ytest) = partition((X, y), 0.7, multi=true);

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
    epochs=20
)

pipe = Standardizer()

pipe = MLJ.TransformedTargetModel(model, transformer=Standardizer())

mach = machine(pipe, X, y)
fit!(mach, verbosity=2)

yha