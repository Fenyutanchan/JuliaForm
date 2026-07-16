using Base64

function validation_output()
    length(ARGS) <= 1 || error(
        "usage: julia Tests/JuliaValidation.jl [generated-output-file|-]",
    )
    source = isempty(ARGS) ? "-" : only(ARGS)
    source == "-" ? read(stdin, String) : read(source, String)
end

function generated_sources(output)
    syntax_sources = String[]
    value_sources = String[]
    error_sources = String[]

    for line in eachline(IOBuffer(output))
        if startswith(line, "SYNTAX\t")
            push!(syntax_sources, String(base64decode(line[8:end])))
        elseif startswith(line, "VALUE\t")
            push!(value_sources, String(base64decode(line[7:end])))
        elseif startswith(line, "ERROR\t")
            push!(error_sources, String(base64decode(line[7:end])))
        else
            error("unexpected Wolfram output: $(repr(line))")
        end
    end

    isempty(syntax_sources) && error("no syntax-validation sources generated")
    isempty(value_sources) && error("no evaluation-validation sources generated")
    isempty(error_sources) && error("no error-validation sources generated")
    syntax_sources, value_sources, error_sources
end

syntax_sources, value_sources, error_sources = generated_sources(validation_output())

const EXPECTED_SYNTAX_SOURCE_COUNT = 32
const EXPECTED_VALUE_SOURCE_COUNT = 123
const EXPECTED_ERROR_SOURCE_COUNT = 47

length(syntax_sources) == EXPECTED_SYNTAX_SOURCE_COUNT || error(
    "syntax source count changed: expected $(EXPECTED_SYNTAX_SOURCE_COUNT), " *
    "got $(length(syntax_sources)); update the validation contract explicitly",
)
length(value_sources) == EXPECTED_VALUE_SOURCE_COUNT || error(
    "value source count changed: expected $(EXPECTED_VALUE_SOURCE_COUNT), " *
    "got $(length(value_sources)); update assertions and the count together",
)
length(error_sources) == EXPECTED_ERROR_SOURCE_COUNT || error(
    "error source count changed: expected $(EXPECTED_ERROR_SOURCE_COUNT), " *
    "got $(length(error_sources)); update assertions and the count together",
)

syntax_sources[3] == "g(x) / f(x)" || error(
    "unexpected canonical quotient source: $(repr(syntax_sources[3]))",
)

value_sources[123] == "1 + (3 // 2) / 2" || error(
    "exact rational in a division chain was not grouped for readability",
)

function parses_completely(source)
    expression = Meta.parseall(source)
    function complete(node)
        node isa Expr || return true
        node.head in (:error, :incomplete) && return false
        all(complete, node.args)
    end
    complete(expression)
end

for source in syntax_sources
    parses_completely(source) || error("incomplete Julia source: $(repr(source))")
end

for source in value_sources
    parses_completely(source) || error("incomplete Julia source: $(repr(source))")
end

for source in error_sources
    parses_completely(source) || error("incomplete Julia source: $(repr(source))")
end

struct JFOffsetVector{T} <: AbstractVector{T}
    data::Vector{T}
end

struct JFOffsetMatrix{T} <: AbstractMatrix{T}
    data::Matrix{T}
end

struct JFEmptyOffsetVector <: AbstractVector{Int} end

Base.size(vector::JFOffsetVector) = (length(vector.data),)
Base.axes(::JFOffsetVector) = (Base.IdentityUnitRange(-1:1),)
Base.getindex(vector::JFOffsetVector, index::Int) = vector.data[index + 2]
Base.size(matrix::JFOffsetMatrix) = size(matrix.data)
Base.axes(::JFOffsetMatrix) = (
    Base.IdentityUnitRange(-1:0),
    Base.IdentityUnitRange(2:4),
)
Base.getindex(matrix::JFOffsetMatrix, row::Int, column::Int) =
    matrix.data[row + 2, column - 1]
Base.size(::JFEmptyOffsetVector) = (0,)
Base.axes(::JFEmptyOffsetVector) = (Base.IdentityUnitRange(5:4),)
Base.getindex(::JFEmptyOffsetVector, index::Int) =
    throw(BoundsError(Base.IdentityUnitRange(5:4), index))

tensor3 = reshape(collect(1:24), 2, 3, 4)
runtimeDict = Dict("x" => 10, "y" => 20)
runtimeTaggedTuple = (:__juliaform_association__, ("x" => 99,))
runtimeRefTaggedTuple = (Ref{Nothing}(), ("x" => 99,))
offsetVector = JFOffsetVector([10, 20, 30])
offsetMatrix = JFOffsetMatrix(reshape(collect(1:6), 2, 3))
emptyOffsetVector = JFEmptyOffsetVector()
emptyVector = Int[]
jfProbeCounts = zeros(Int, 9)
jfUnaryProbeCounts = zeros(Int, 9)
jfEagerComparisonCounts = zeros(Int, 18)
jfArcTanOrder = Int[]
jfTimesEvents = Int[]
runtimeZeroArray = [0.0]
runtimeNegativeZeroArray = [-0.0]
runtimeComplexZeroArray = [Complex(1.0, 0.0)]
runtimeComplexNegativeZeroArray = [Complex(1.0, -0.0)]
runtimeZeroPair = "x" => 0.0
runtimeNegativeZeroPair = "x" => -0.0
runtimeZeroTuple = (0.0, Complex(1.0, 0.0))
runtimeNegativeZeroTuple = (-0.0, Complex(1.0, -0.0))
runtimeArrayKey = [1, 2]
runtimeContainerKeyDict = Dict(runtimeArrayKey => 10)
runtimeAmbiguousDict = Dict(0.0 => 10, -0.0 => 20)
runtimeNaNArray = [NaN]
runtimeComplexNaN = Complex(NaN, 0.0)
runtimeMissing = missing
runtimeOrderingArray = [1]

function jfProbe(index, value)
    jfProbeCounts[index] += 1
    value
end

function jfUnaryProbe(index, value)
    jfUnaryProbeCounts[index] += 1
    value
end

function jfEagerProbe(index, value)
    jfEagerComparisonCounts[index] += 1
    value
end

function jfArcTanProbe(index, value)
    push!(jfArcTanOrder, index)
    value
end

function jfTimesOrderProbe(index, value)
    push!(jfTimesEvents, index)
    value
end


struct JFReciprocalProbe
    value::Float64
end


function jfReciprocalProbe(index, value)
    push!(jfTimesEvents, index)
    JFReciprocalProbe(value)
end


function Base.inv(probe::JFReciprocalProbe)
    push!(jfTimesEvents, 20)
    inv(probe.value)
end

runtimeAssociationKey(index) = index == 1 ? 1 : 1.0
runtimeSignedZeroKey(index) = index == 1 ? 0.0 : -0.0
runtimeComplexSignedZeroKey(index) =
    Complex(1.0, index == 1 ? 0.0 : -0.0)

values = [Core.eval(Main, Meta.parse(source)) for source in value_sources]

@assert values[1] == 1 // 3
@assert values[2] == Complex(1 // 2, 2 // 3)
@assert values[3] == big"1267650600228229401496703205376"
@assert values[4] == BigFloat("1.25"; precision = 100)
@assert values[5] == "a\n\"b\\c\$"
@assert values[6] == [1, 2, 3]
@assert values[7] == [1 2; 3 4]
@assert size(values[8]) == (2, 1) && vec(values[8]) == [1, 2]
@assert values[9] == Dict("x" => 1, "y" => [2, 3])
@assert values[10] == 3
@assert values[11] == 20
@assert values[12] == ("x" => [1, 2])
@assert values[13] == BigFloat("1.25e100"; precision = 100)
@assert values[14] == ℯ
@assert values[15] == 1.0
@assert values[16] == 5
@assert values[17] == 2
@assert values[18] == [3, 4]
@assert values[19] == true
@assert values[20] == false
@assert values[21] == true
@assert values[22] == true
@assert values[23] == true
@assert values[24] == true
@assert values[25] == true
@assert values[26] == true
@assert values[27] == false
@assert values[28] == [1, 2, 3]
@assert values[29] == 3
@assert values[30] == [1, 3]
@assert values[31] == [1, 3]
@assert values[32] == 20
@assert values[33] == Dict("x" => 10, "y" => 20)
@assert values[34] == 21
@assert values[35] == [2 8 14 20; 4 10 16 22; 6 12 18 24]
@assert values[36] == false
@assert values[37] == false
@assert values[38] == false
@assert values[39] == [1, 2]
@assert values[40] == [2, 3]
@assert values[41] == 20
@assert values[42] == [4, 2]
@assert values[43] == 5
@assert values[44] == [4, 10, 16, 22]
@assert values[45] == Dict("x" => 10, "y" => 20)
@assert values[46] == Dict("x" => 11, "y" => 21)
@assert values[47] == 2
@assert values[48] == [1, 2]
@assert values[49] == 10
@assert values[50] == 30
@assert values[51] == 3
@assert values[52] == 10
@assert values[53] == 20
@assert values[54] == Dict("x" => 1)
@assert values[55] == [Dict("x" => 1)]
@assert values[56] == true
@assert values[57] == true
@assert values[58] == true
@assert values[59] == true
@assert values[60] == true
@assert values[61] == true
@assert values[62] == true
@assert values[63] == true
@assert values[64] == false
@assert values[65] == true
@assert values[66] == false
@assert values[67] == true
@assert values[68] == [10, 20, 30]
@assert values[69] == [1, 3, 5]
@assert values[70] == [1, 2]
@assert values[71] == false
@assert values[72] == false
@assert values[73] == false
@assert values[74] == false
@assert values[75] == false
@assert values[76] == false
@assert values[77] == true
@assert values[78] == false
@assert values[79] == true
@assert values[80] == false
@assert values[81] == true
@assert values[82] == false
@assert values[83] == true
@assert values[84] == false
@assert values[85] == Dict(1 => 20, "x" => 30)
@assert length(values[86]) == 1 && only(Base.values(values[86])) == 20
@assert length(values[87]) == 1 && only(Base.values(values[87])) == 20
@assert length(values[88]) == 1 && only(Base.values(values[88])) == 20
@assert values[89] === 1
@assert values[90] === 1
@assert isempty(values[91])
@assert isempty(values[92])
@assert isempty(values[93])
@assert isempty(values[94])
@assert isempty(values[95])
@assert isempty(values[96])
@assert isempty(values[97])
@assert isempty(values[98])
@assert isempty(values[99])
@assert isempty(values[100])
@assert isempty(values[101])
@assert values[102] === missing
@assert values[103] === missing
@assert isequal(values[104], Dict("z" => missing, "x" => 1))
@assert values[105] == atan(1.0, 1.0)
@assert values[106] == 1.5
@assert values[107] == 20
@assert values[108] == 20
@assert length(values[109]) == 1 && only(Base.values(values[109])) == 20
@assert isempty(values[110])
@assert isempty(values[111])
@assert values[112] === offsetVector
@assert values[113] === offsetVector
@assert length(values[114]) == 1 && only(values[114]) === offsetVector
@assert length(values[115]) == 1 && values[115]["x"] === offsetVector
@assert values[116] == true
@assert values[117] == true
@assert values[118] == true
@assert values[119] == false
@assert values[120] == true
@assert values[121] == true
@assert values[122] == 0.125
@assert values[123] == (7 // 4)
@assert jfProbeCounts == ones(Int, 9)
@assert jfUnaryProbeCounts == ones(Int, 9)
@assert jfEagerComparisonCounts == ones(Int, 18)
@assert jfArcTanOrder == [1, 2]
@assert jfTimesEvents == [1, 2, 20, 3, 4, 20, 5, 20]

expected_error_fragments = [
    "positional Part on an arbitrary Dict is unsupported",
    "positional Part on an arbitrary Dict is unsupported",
    "Part applied below the available expression depth",
    "Part applied below the available expression depth",
    "Span step points away from its endpoint",
    "Span step points away from its endpoint",
    "Association keys cannot be materialized as a Julia Dict",
    "Association keys cannot be materialized as a Julia Dict",
    "Association keys cannot be materialized as a Julia Dict",
    "Association keys cannot be materialized as a Julia Dict",
    "Association keys cannot be materialized as a Julia Dict",
    "SameQ or UnsameQ on a Julia Dict is unsupported",
    "SameQ or UnsameQ on a Julia Dict is unsupported",
    "container-valued Association keys cannot be represented faithfully",
    "container-valued Association keys cannot be represented faithfully",
    "container-valued Association keys cannot be represented faithfully",
    "container-valued Association keys cannot be represented faithfully",
    "runtime Dict contains keys that are ambiguous",
    "container-valued Association keys cannot be represented faithfully",
    "SameQ or UnsameQ on a Julia Dict is unsupported",
    "SameQ or UnsameQ on a Julia Dict is unsupported",
    "comparisons on a Julia Dict are unsupported",
    "comparisons on a Julia Dict are unsupported",
    "comparisons on a Julia Dict are unsupported",
    "comparisons on a Julia Dict are unsupported",
    "comparisons on a Julia Dict are unsupported",
    "comparisons on a Julia Dict are unsupported",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "Wolfram comparisons involving Indeterminate",
    "ordinary Wolfram equality involving Boolean or Null mixed structure",
    "ordinary Wolfram equality involving Boolean or Null mixed structure",
    "Wolfram ordering comparisons require non-Boolean real scalars",
    "Wolfram ordering comparisons require non-Boolean real scalars",
    "ordinary Wolfram comparisons involving Missing",
    "ordinary Wolfram comparisons involving Missing",
    "ordinary Wolfram equality involving Boolean or Null mixed structure",
    "ordinary Wolfram equality involving Boolean or Null mixed structure",
    "Wolfram ordering comparisons require non-Boolean real scalars",
    "Wolfram ordering comparisons require non-Boolean real scalars",
    "ordinary Wolfram equality involving Boolean or Null mixed structure",
]

for (source, expected_fragment) in zip(
    error_sources,
    expected_error_fragments,
)
    caught = nothing
    try
        Core.eval(Main, Meta.parse(source))
    catch exception
        caught = exception
    end
    caught isa ArgumentError || error(
        "expected ArgumentError from $(repr(source)), got $(repr(caught))",
    )
    occursin(expected_fragment, caught.msg) ||
        error("unexpected Part error: $(caught.msg)")
end

println(
    "Julia validation passed: ",
    length(syntax_sources),
    " parsed, ",
    length(values),
    " evaluated, ",
    length(error_sources),
    " rejected",
)
