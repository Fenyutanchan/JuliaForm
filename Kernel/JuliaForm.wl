PackageExported[JuliaForm]

JuliaForm::usage =
    "JuliaForm[expr] displays expr as a Julia language expression. " <>
    "ToString[JuliaForm[expr], OutputForm] returns the Julia source text.";

JuliaForm::argx =
    "JuliaForm called with `1` arguments; 1 argument is expected.";

JuliaForm::unsupported =
    "Cannot convert an expression containing `1` to Julia source.";

SyntaxInformation[JuliaForm] = {"ArgumentsPattern" -> {_}};

$precedenceLambda = 10;
$precedenceTernary = 20;
$precedencePair = 30;
$precedenceOr = 40;
$precedenceAnd = 50;
$precedenceComparison = 60;
$precedenceRange = 65;
$precedenceAdditive = 70;
$precedenceMultiplicative = 80;
$precedenceUnary = 85;
$precedencePower = 90;
$precedenceCall = 100;
$precedenceAtom = 110;

$juliaKeywords = {
    "abstract", "baremodule", "begin", "break", "catch", "const",
    "continue", "do", "else", "elseif", "end", "export", "false",
    "finally", "for", "function", "global", "if", "import", "in",
    "isa", "let", "local", "macro", "missing", "module", "mutable",
    "nothing", "primitive", "public", "quote", "return", "struct",
    "true", "try", "using", "where", "while"
};

$juliaIdentifierPattern =
    RegularExpression["^[\\p{L}_][\\p{L}\\p{N}_]*[!?]?$"];

SetAttributes[renderJulia, HoldAllComplete];

renderJulia[expr_] := Catch[
    First[emitHeld[HoldComplete[expr]]],
    renderFailureTag,
    Function[{reason, tag},
        Message[JuliaForm::unsupported, reason];
        $Failed
    ]
];

failUnsupported[reason_String] := Throw[reason, renderFailureTag];

heldItems[held_HoldComplete] := Apply[List, Map[HoldComplete, held]];

renderHeld[held_HoldComplete] := First[emitHeld[held]];

renderHeldAt[held_HoldComplete, minimum_Integer] := Module[{emitted},
    emitted = emitHeld[held];
    If[
        emitted[[2]] < minimum,
        "(" <> emitted[[1]] <> ")",
        emitted[[1]]
    ]
];

integerCode[n_Integer] := If[
    -9223372036854775808 <= n <= 9223372036854775807,
    ToString[n, InputForm],
    "big" <> juliaString[ToString[n, InputForm]]
];

normalizeRealString[string_String] := Module[{result},
    result = StringReplace[string, "*^" -> "e"];
    result = StringReplace[result, ".e" -> ".0e"];
    If[StringEndsQ[result, "."], result <> "0", result]
];

realCode[x_Real] := Module[{raw, mantissa, bits},
    raw = ToString[x, InputForm];
    If[
        Precision[x] === MachinePrecision,
        normalizeRealString[raw],
        mantissa = StringReplace[
            raw,
            RegularExpression["`{1,2}[^*]*(?=\\*\\^|$)"] -> ""
        ];
        bits = Max[2, Ceiling[Precision[x] Log[2, 10]]];
        "BigFloat(" <> juliaString[normalizeRealString[mantissa]] <>
            "; precision = " <> ToString[bits, InputForm] <> ")"
    ]
];

juliaString[string_String] :=
    "\"" <> StringJoin[escapeJuliaCharacter /@ Characters[string]] <> "\"";

escapeJuliaCharacter["\\"] := "\\\\";
escapeJuliaCharacter["\""] := "\\\"";
escapeJuliaCharacter["$"] := "\\$";
escapeJuliaCharacter["\b"] := "\\b";
escapeJuliaCharacter["\t"] := "\\t";
escapeJuliaCharacter["\n"] := "\\n";
escapeJuliaCharacter["\f"] := "\\f";
escapeJuliaCharacter["\r"] := "\\r";
escapeJuliaCharacter[character_String] := Module[{code},
    code = First[ToCharacterCode[character]];
    If[
        code < 32 || code == 127,
        "\\x" <> ToUpperCase[IntegerString[code, 16, 2]],
        character
    ]
];

juliaVarIdentifier[name_String] :=
    "var\"" <>
        StringReplace[name, {"\\" -> "\\\\", "\"" -> "\\\""}] <>
        "\"";

symbolCode[HoldComplete[symbol_Symbol]] := Module[
    {name, context, qualified},
    name = SymbolName[Unevaluated[symbol]];
    context = Context[Unevaluated[symbol]];
    qualified = If[
        MemberQ[{"System`", "Global`"}, context],
        name,
        context <> name
    ];
    If[
        context =!= "System`" && context =!= "Global`",
        juliaVarIdentifier[qualified],
        If[
            StringMatchQ[name, $juliaIdentifierPattern] &&
                FreeQ[$juliaKeywords, name],
            name,
            juliaVarIdentifier[name]
        ]
    ]
];

functionCode[held_HoldComplete] := Switch[
    held,
    HoldComplete[Sin], "sin",
    HoldComplete[Cos], "cos",
    HoldComplete[Tan], "tan",
    HoldComplete[Cot], "cot",
    HoldComplete[Sec], "sec",
    HoldComplete[Csc], "csc",
    HoldComplete[ArcSin], "asin",
    HoldComplete[ArcCos], "acos",
    HoldComplete[ArcTan], "atan",
    HoldComplete[ArcCot], "acot",
    HoldComplete[ArcSec], "asec",
    HoldComplete[ArcCsc], "acsc",
    HoldComplete[Sinh], "sinh",
    HoldComplete[Cosh], "cosh",
    HoldComplete[Tanh], "tanh",
    HoldComplete[Coth], "coth",
    HoldComplete[Sech], "sech",
    HoldComplete[Csch], "csch",
    HoldComplete[ArcSinh], "asinh",
    HoldComplete[ArcCosh], "acosh",
    HoldComplete[ArcTanh], "atanh",
    HoldComplete[ArcCoth], "acoth",
    HoldComplete[ArcSech], "asech",
    HoldComplete[ArcCsch], "acsch",
    HoldComplete[Exp], "exp",
    HoldComplete[Sqrt], "sqrt",
    HoldComplete[Log], "log",
    HoldComplete[Abs], "abs",
    HoldComplete[Sign], "sign",
    HoldComplete[Min], "min",
    HoldComplete[Max], "max",
    HoldComplete[Mod], "mod",
    HoldComplete[GCD], "gcd",
    HoldComplete[LCM], "lcm",
    HoldComplete[Conjugate], "conj",
    HoldComplete[Re], "real",
    HoldComplete[Im], "imag",
    HoldComplete[Arg], "angle",
    HoldComplete[Factorial], "factorial",
    HoldComplete[Binomial], "binomial",
    HoldComplete[Inverse], "inv",
    HoldComplete[Det], "det",
    HoldComplete[Tr], "tr",
    _, If[
        MatchQ[held, HoldComplete[_Symbol]],
        symbolCode[held],
        renderHeldAt[held, $precedenceCall]
    ]
];

$unaryMappedFunctionHeads = {
    HoldComplete[Sin], HoldComplete[Cos], HoldComplete[Tan],
    HoldComplete[Cot], HoldComplete[Sec], HoldComplete[Csc],
    HoldComplete[ArcSin], HoldComplete[ArcCos], HoldComplete[ArcCot],
    HoldComplete[ArcSec], HoldComplete[ArcCsc], HoldComplete[Sinh],
    HoldComplete[Cosh], HoldComplete[Tanh], HoldComplete[Coth],
    HoldComplete[Sech], HoldComplete[Csch], HoldComplete[ArcSinh],
    HoldComplete[ArcCosh], HoldComplete[ArcTanh], HoldComplete[ArcCoth],
    HoldComplete[ArcSech], HoldComplete[ArcCsch], HoldComplete[Exp],
    HoldComplete[Sqrt], HoldComplete[Abs], HoldComplete[Sign],
    HoldComplete[Conjugate], HoldComplete[Re], HoldComplete[Im],
    HoldComplete[Arg], HoldComplete[Factorial], HoldComplete[Inverse],
    HoldComplete[Det], HoldComplete[Tr]
};

$mappedFunctionHeads = Join[
    $unaryMappedFunctionHeads,
    {
        HoldComplete[ArcTan], HoldComplete[Log], HoldComplete[Min],
        HoldComplete[Max], HoldComplete[Mod], HoldComplete[GCD],
        HoldComplete[LCM], HoldComplete[Binomial]
    }
];

mappedFunctionHeadQ[head_HoldComplete] :=
    MemberQ[$mappedFunctionHeads, head];

mappedFunctionArityQ[head_HoldComplete, count_Integer] := Which[
    MemberQ[$unaryMappedFunctionHeads, head], count == 1,
    head === HoldComplete[ArcTan], MemberQ[{1, 2}, count],
    head === HoldComplete[Log], MemberQ[{1, 2}, count],
    MemberQ[{HoldComplete[Min], HoldComplete[Max]}, head], count >= 1,
    head === HoldComplete[Mod], count == 2,
    MemberQ[{HoldComplete[GCD], HoldComplete[LCM]}, head], count >= 1,
    head === HoldComplete[Binomial], count == 2,
    True, False
];

heldHeadName[HoldComplete[symbol_Symbol]] :=
    SymbolName[Unevaluated[symbol]];

emitHeld[HoldComplete[True]] := {"true", $precedenceAtom};
emitHeld[HoldComplete[False]] := {"false", $precedenceAtom};
emitHeld[HoldComplete[Null]] := {"nothing", $precedenceAtom};
emitHeld[HoldComplete[Pi]] := {"pi", $precedenceAtom};
emitHeld[HoldComplete[E]] := {
    FromCharacterCode[16^^212F],
    $precedenceAtom
};
emitHeld[HoldComplete[EulerGamma]] :=
    {"Base.MathConstants.eulergamma", $precedenceAtom};
emitHeld[HoldComplete[GoldenRatio]] :=
    {"Base.MathConstants.golden", $precedenceAtom};
emitHeld[HoldComplete[Catalan]] :=
    {"Base.MathConstants.catalan", $precedenceAtom};
emitHeld[HoldComplete[Indeterminate]] := {"NaN", $precedenceAtom};
emitHeld[HoldComplete[DirectedInfinity[1]]] := {"Inf", $precedenceAtom};
emitHeld[HoldComplete[DirectedInfinity[-1]]] := {"-Inf", $precedenceUnary};
emitHeld[HoldComplete[DirectedInfinity[]]] := failUnsupported["ComplexInfinity"];
emitHeld[HoldComplete[DirectedInfinity[_]]] :=
    failUnsupported["a non-real DirectedInfinity"];

emitHeld[HoldComplete[n_Integer]] := {
    integerCode[n],
    If[n < 0 && StringStartsQ[integerCode[n], "-"],
        $precedenceUnary,
        $precedenceAtom
    ]
};

emitHeld[HoldComplete[r_Rational]] := Module[{numerator, denominator},
    numerator = Numerator[r];
    denominator = Denominator[r];
    {
        integerCode[numerator] <> " // " <> integerCode[denominator],
        $precedenceMultiplicative
    }
];

emitHeld[HoldComplete[x_Real]] := {
    realCode[x],
    If[x < 0 && Precision[x] === MachinePrecision,
        $precedenceUnary,
        $precedenceAtom
    ]
};

emitHeld[HoldComplete[z_Complex]] := Module[{real, imaginary},
    real = Re[z];
    imaginary = Im[z];
    Which[
        real === 0 && imaginary === 1,
            {"im", $precedenceAtom},
        real === 0 && imaginary === -1,
            {"-im", $precedenceUnary},
        True,
            {
                "Complex(" <> renderHeld[heldValue[real]] <> ", " <>
                    renderHeld[heldValue[imaginary]] <> ")",
                $precedenceCall
            }
    ]
];

emitHeld[HoldComplete[string_String]] :=
    {juliaString[string], $precedenceAtom};

emitHeld[HoldComplete[HoldForm[inner_]]] := emitHeld[HoldComplete[inner]];

emitHeld[HoldComplete[Plus[terms___]]] := Module[{items},
    items = heldItems[HoldComplete[terms]];
    If[AnyTrue[items, listExpressionQ],
        failUnsupported["held arithmetic on a literal List"]
    ];
    emitPlusItems[items]
];

emitHeld[HoldComplete[Times[factors___]]] := Module[{items},
    items = heldItems[HoldComplete[factors]];
    If[AnyTrue[items, listExpressionQ],
        failUnsupported["held arithmetic on a literal List"]
    ];
    emitTimesItems[items]
];

emitHeld[HoldComplete[Power[_List, _]]] :=
    failUnsupported["held arithmetic on a literal List"];

emitHeld[HoldComplete[Power[_, _List]]] :=
    failUnsupported["held arithmetic on a literal List"];

emitHeld[HoldComplete[Power[E, exponent_]]] := {
    "exp(" <> renderHeld[HoldComplete[exponent]] <> ")",
    $precedenceCall
};

emitHeld[HoldComplete[Power[base_, Rational[1, 2]]]] := {
    "sqrt(" <> renderHeld[HoldComplete[base]] <> ")",
    $precedenceCall
};

emitHeld[HoldComplete[Power[base_, -1]]] := {
    "inv(" <> renderHeld[HoldComplete[base]] <> ")",
    $precedenceCall
};

emitHeld[HoldComplete[Power[base_, exponent_]]] := {
    renderHeldAt[HoldComplete[base], $precedencePower + 1] <>
        " ^ " <>
        renderHeldAt[HoldComplete[exponent], $precedencePower],
    $precedencePower
};

negativeRealNumericQ[value_] :=
    NumberQ[value] && TrueQ[Im[value] == 0] && TrueQ[value < 0];

heldValue[value_] := With[{evaluated = value}, HoldComplete[evaluated]];

signedTerm[held : HoldComplete[value : (_Integer | _Rational | _Real)]] /;
        negativeRealNumericQ[value] :=
    {True, renderHeld[heldValue[-value]]};

signedTerm[HoldComplete[
        Times[coefficient : (_Integer | _Rational | _Real), rest___]
    ]] /;
        negativeRealNumericQ[coefficient] := Module[{positive, items},
    positive = -coefficient;
    items = heldItems[HoldComplete[rest]];
    If[positive =!= 1, items = Prepend[items, heldValue[positive]]];
    With[{emitted = emitTimesItems[items]},
        {
            True,
            If[
                emitted[[2]] <= $precedenceAdditive,
                "(" <> emitted[[1]] <> ")",
                emitted[[1]]
            ]
        }
    ]
];

signedTerm[held_HoldComplete] :=
    {False, renderHeldAt[held, $precedenceAdditive + 1]};

emitPlusItems[{}] := {"0", $precedenceAtom};

emitPlusItems[items_List] := Module[{result, signed},
    result = renderHeldAt[First[items], $precedenceAdditive];
    Do[
        signed = signedTerm[item];
        result = result <>
            If[signed[[1]], " - ", " + "] <>
            signed[[2]],
        {item, Rest[items]}
    ];
    {result, $precedenceAdditive}
];

reciprocalFactorQ[HoldComplete[Power[_, -1]]] := True;
reciprocalFactorQ[_] := False;

reciprocalBase[HoldComplete[Power[base_, -1]]] := HoldComplete[base];

emitProductItems[{}] := {"1", $precedenceAtom};
emitProductItems[{item_}] := emitHeld[item];

emitProductItems[items_List] := Module[{rest, emitted},
    If[
        First[items] === HoldComplete[-1],
        rest = emitProductItems[Rest[items]];
        Return[{
            "-" <>
                If[rest[[2]] < $precedenceUnary,
                    "(" <> rest[[1]] <> ")",
                    rest[[1]]
                ],
            $precedenceUnary
        }]
    ];
    emitted = renderHeldAt[#, $precedenceMultiplicative] & /@ items;
    {StringRiffle[emitted, " * "], $precedenceMultiplicative}
];

timesReordersEvaluationQ[items_List] := Module[{flags},
    flags = reciprocalFactorQ /@ items;
    Count[flags, True] > 1 ||
        MemberQ[Partition[flags, 2, 1], {True, False}]
];

emitBoundTimesItems[items_List] := Module[
    {names},
    names = Table["__jf_factor" <> ToString[index], {index, Length[items]}];
    {
        "((" <> StringRiffle[names, ", "] <> ") -> " <>
            StringRiffle[names, " * "] <> ")(" <>
            StringRiffle[renderHeld /@ items, ", "] <> ")",
        $precedenceCall
    }
];

emitTimesItems[items_List] := Module[
    {numeratorItems, denominatorItems, numerator, denominator},
    If[timesReordersEvaluationQ[items], Return[emitBoundTimesItems[items]]];
    numeratorItems = Select[items, Not[reciprocalFactorQ[#]] &];
    denominatorItems = reciprocalBase /@
        Select[items, reciprocalFactorQ];
    numerator = emitProductItems[numeratorItems];
    If[denominatorItems === {}, Return[numerator]];
    denominator = If[
        Length[denominatorItems] == 1,
        renderHeldAt[First[denominatorItems], $precedenceMultiplicative + 1],
        "(" <>
            StringRiffle[
                renderHeldAt[#, $precedenceMultiplicative] & /@
                    denominatorItems,
                " * "
            ] <>
            ")"
    ];
    {
        If[
            numeratorItems === {},
            "1",
            If[
                numerator[[2]] < $precedenceMultiplicative,
                "(" <> numerator[[1]] <> ")",
                numerator[[1]]
            ]
        ] <>
            " / " <> denominator,
        $precedenceMultiplicative
    }
];

emitHeld[HoldComplete[Less[items___]]] :=
    emitComparison["<", heldItems[HoldComplete[items]]];
emitHeld[HoldComplete[LessEqual[items___]]] :=
    emitComparison["<=", heldItems[HoldComplete[items]]];
emitHeld[HoldComplete[Greater[items___]]] :=
    emitComparison[">", heldItems[HoldComplete[items]]];
emitHeld[HoldComplete[GreaterEqual[items___]]] :=
    emitComparison[">=", heldItems[HoldComplete[items]]];
emitHeld[HoldComplete[Equal[items___]]] :=
    emitComparison["==", heldItems[HoldComplete[items]]];

emitHeld[HoldComplete[Inequality[items___]]] :=
    emitMixedInequality[heldItems[HoldComplete[items]]];

emitTrueAfterEvaluation[{}] := {"true", $precedenceAtom};
emitTrueAfterEvaluation[{item_HoldComplete}] := {
    "((__jf_value1) -> true)(" <> renderHeld[item] <> ")",
    $precedenceCall
};

emitComparison[_, items_List] /; Length[items] < 2 :=
    emitTrueAfterEvaluation[items];

emitComparison[operator_String, items_List] := Module[{},
    If[
        AnyTrue[items, containsLiteralListQ],
        failUnsupported["a comparison involving a literal List"]
    ];
    emitBoundComparison[
        ConstantArray[operator, Length[items] - 1],
        items
    ]
];

$comparisonGuardRuntimeCode = StringJoin[
    "__jf_equality_issue = nothing; ",
    "__jf_equality_issue = function (__jf_item) ",
        "if __jf_item isa AbstractDict; return :dict; ",
        "elseif __jf_item === missing; return :missing; ",
        "elseif __jf_item isa AbstractFloat; ",
            "return isnan(__jf_item) ? :nan : nothing; ",
        "elseif __jf_item isa Complex; ",
            "__jf_issue = __jf_equality_issue(real(__jf_item)); ",
            "return isnothing(__jf_issue) ? ",
                "__jf_equality_issue(imag(__jf_item)) : __jf_issue; ",
        "elseif __jf_item isa AbstractArray || __jf_item isa Tuple; ",
            "for __jf_nested in __jf_item; ",
                "__jf_issue = __jf_equality_issue(__jf_nested); ",
                "isnothing(__jf_issue) || return __jf_issue; end; ",
        "elseif __jf_item isa Pair; ",
            "__jf_issue = __jf_equality_issue(first(__jf_item)); ",
            "return isnothing(__jf_issue) ? ",
                "__jf_equality_issue(last(__jf_item)) : __jf_issue; ",
        "end; nothing end; ",
    "__jf_contains_boolean_or_nothing = nothing; ",
    "__jf_contains_boolean_or_nothing = function (__jf_item) ",
        "if __jf_item isa Bool || __jf_item === nothing; return true; end; ",
        "if __jf_item isa AbstractArray || __jf_item isa Tuple; ",
            "return any(__jf_contains_boolean_or_nothing, __jf_item); ",
        "elseif __jf_item isa Pair; ",
            "return __jf_contains_boolean_or_nothing(first(__jf_item)) || ",
                "__jf_contains_boolean_or_nothing(last(__jf_item)); ",
        "end; false end; ",
    "__jf_require_equality_pair = function (__jf_left, __jf_right) ",
        "for __jf_item in (__jf_left, __jf_right); ",
            "__jf_issue = __jf_equality_issue(__jf_item); ",
            "__jf_issue === :dict && throw(ArgumentError(",
                "\"comparisons on a Julia Dict are unsupported because ",
                    "Association order is unavailable\")); ",
            "__jf_issue === :nan && throw(ArgumentError(",
                "\"Wolfram comparisons involving Indeterminate cannot be ",
                    "represented as a Julia Bool\")); ",
            "__jf_issue === :missing && throw(ArgumentError(",
                "\"ordinary Wolfram comparisons involving Missing cannot ",
                    "be represented as a Julia Bool\")); end; ",
        "if __jf_contains_boolean_or_nothing(__jf_left) || ",
                "__jf_contains_boolean_or_nothing(__jf_right); ",
            "((__jf_left isa Bool && __jf_right isa Bool) || ",
                "(__jf_left === nothing && __jf_right === nothing)) || ",
                "throw(ArgumentError(\"ordinary Wolfram equality involving ",
                    "Boolean or Null mixed structure is unsupported\")); ",
        "end; nothing end; ",
    "__jf_require_ordering_pair = function (__jf_left, __jf_right) ",
        "for __jf_item in (__jf_left, __jf_right); ",
            "(__jf_item isa Real && !(__jf_item isa Bool)) || ",
                "throw(ArgumentError(\"Wolfram ordering comparisons require ",
                    "non-Boolean real scalars\")); ",
            "(__jf_item isa AbstractFloat && isnan(__jf_item)) && ",
                "throw(ArgumentError(\"Wolfram comparisons involving ",
                    "Indeterminate cannot be represented as a Julia Bool\")); ",
        "end; nothing end; "
];

emitBoundComparison[operators_List, items_List] := Module[
    {names, body, guards},
    names = Table["__jf_value" <> ToString[index], {index, Length[items]}];
    body = First[names];
    Do[
        body = body <> " " <> operators[[index]] <> " " <>
            names[[index + 1]],
        {index, Length[operators]}
    ];
    guards = StringJoin@Table[
        If[
            MemberQ[{"==", "!="}, operators[[index]]],
            "__jf_require_equality_pair(",
            "__jf_require_ordering_pair("
        ] <> names[[index]] <> ", " <> names[[index + 1]] <> "); ",
        {index, Length[operators]}
    ];
    {
        "((" <> StringRiffle[names, ", "] <> ") -> begin " <>
            $comparisonGuardRuntimeCode <> guards <> body <> " end)(" <>
            StringRiffle[renderHeld /@ items, ", "] <> ")",
        $precedenceCall
    }
];

inequalityOperator[HoldComplete[Less]] := "<";
inequalityOperator[HoldComplete[LessEqual]] := "<=";
inequalityOperator[HoldComplete[Greater]] := ">";
inequalityOperator[HoldComplete[GreaterEqual]] := ">=";
inequalityOperator[HoldComplete[Equal]] := "==";
inequalityOperator[HoldComplete[Unequal]] := "!=";
inequalityOperator[_] := failUnsupported["an unknown Inequality operator"];

emitMixedInequality[items_List] := Module[
    {expressions, operators},
    If[Length[items] == 1, Return[emitTrueAfterEvaluation[items]]];
    If[
        Length[items] < 3 || EvenQ[Length[items]],
        failUnsupported["a malformed Inequality"]
    ];
    expressions = items[[1 ;; ;; 2]];
    operators = inequalityOperator /@ items[[2 ;; ;; 2]];
    If[
        AnyTrue[expressions, containsLiteralListQ],
        failUnsupported["a comparison involving a literal List"]
    ];
    emitBoundComparison[operators, expressions]
];

emitHeld[HoldComplete[Unequal[items___]]] :=
    emitPairwiseComparison[
        "!=",
        heldItems[HoldComplete[items]],
        All
    ];

emitHeld[HoldComplete[SameQ[items___]]] :=
    emitStructuralComparison[heldItems[HoldComplete[items]], True];

emitHeld[HoldComplete[UnsameQ[items___]]] :=
    emitStructuralComparison[heldItems[HoldComplete[items]], False];

emitPairwiseComparison[operator_String, items_List, mode_] := Module[
    {names, pairs, clauses, body, guards},
    If[Length[items] < 2, Return[emitTrueAfterEvaluation[items]]];
    If[
        AnyTrue[items, containsLiteralListQ],
        failUnsupported["a comparison involving a literal List"]
    ];
    names = Table["__jf_value" <> ToString[index], {index, Length[items]}];
    pairs = If[
        mode === First,
        Thread[{ConstantArray[First[names], Length[names] - 1], Rest[names]}],
        Subsets[names, {2}]
    ];
    clauses = (
        #[[1]] <> " " <> operator <> " " <> #[[2]]
    ) & /@ pairs;
    body = If[
        Length[clauses] == 1,
        First[clauses],
        StringRiffle["(" <> # <> ")" & /@ clauses, " && "]
    ];
    guards = StringJoin[
        "__jf_require_equality_pair(" <> #[[1]] <> ", " <> #[[2]] <>
            "); " & /@ pairs
    ];
    {
        "((" <> StringRiffle[names, ", "] <> ") -> begin " <>
            $comparisonGuardRuntimeCode <> guards <> body <> " end)(" <>
            StringRiffle[renderHeld /@ items, ", "] <> ")",
        $precedenceCall
    }
];

$structuralEqualityRuntimeCode = StringJoin[
    "__jf_same = nothing; ",
    "__jf_same = function (__jf_left, __jf_right) ",
        "typeof(__jf_left) === typeof(__jf_right) || return false; ",
        "if __jf_left isa AbstractFloat; ",
            "return isequal(__jf_left, __jf_right) || ",
                "(iszero(__jf_left) && iszero(__jf_right)); ",
        "elseif __jf_left isa Complex; ",
            "return __jf_same(real(__jf_left), real(__jf_right)) && ",
                "__jf_same(imag(__jf_left), imag(__jf_right)); ",
        "elseif __jf_left isa AbstractArray; ",
            "axes(__jf_left) == axes(__jf_right) || return false; ",
            "return all(__jf_pair -> ",
                "__jf_same(first(__jf_pair), last(__jf_pair)), ",
                "zip(__jf_left, __jf_right)); ",
        "elseif __jf_left isa Pair; ",
            "return __jf_same(first(__jf_left), first(__jf_right)) && ",
                "__jf_same(last(__jf_left), last(__jf_right)); ",
        "elseif __jf_left isa Tuple; ",
            "return all(__jf_pair -> ",
                "__jf_same(first(__jf_pair), last(__jf_pair)), ",
                "zip(__jf_left, __jf_right)); ",
        "elseif __jf_left isa AbstractDict; ",
            "throw(ArgumentError(\"SameQ or UnsameQ on a Julia Dict is ",
                "unsupported because Association order is unavailable\")); ",
    "end; isequal(__jf_left, __jf_right) end; "
];

$associationKeyGuardRuntimeCode = StringJoin[
    "__jf_key_has_unsupported_container = nothing; ",
    "__jf_key_has_unsupported_container = function (__jf_key) ",
        "if __jf_key isa AbstractArray || __jf_key isa AbstractDict; ",
            "return true; ",
        "elseif __jf_key isa Pair; ",
            "return __jf_key_has_unsupported_container(first(__jf_key)) || ",
                "__jf_key_has_unsupported_container(last(__jf_key)); ",
        "elseif __jf_key isa Tuple; ",
            "return any(__jf_key_has_unsupported_container, __jf_key); ",
        "end; false end; ",
    "__jf_require_supported_association_key = (__jf_key) -> ",
        "(__jf_key_has_unsupported_container(__jf_key) && ",
            "throw(ArgumentError(\"container-valued Association keys ",
                "cannot be represented faithfully as Julia Dict keys\")); ",
        "__jf_key); "
];

structuralEqualityClause[{left_String, right_String}] :=
    "__jf_same(" <> left <> ", " <> right <> ")";

emitStructuralComparison[items_List, equalQ_] := Module[
    {names, pairs, clauses, body},
    If[Length[items] < 2, Return[emitTrueAfterEvaluation[items]]];
    If[
        AnyTrue[items, containsLiteralListQ],
        failUnsupported["SameQ or UnsameQ on a literal List"]
    ];
    names = Table["__jf_value" <> ToString[index], {index, Length[items]}];
    pairs = If[
        TrueQ[equalQ],
        Thread[{ConstantArray[First[names], Length[names] - 1], Rest[names]}],
        Subsets[names, {2}]
    ];
    clauses = structuralEqualityClause /@ pairs;
    If[Not[TrueQ[equalQ]], clauses = "!(" <> # <> ")" & /@ clauses];
    body = If[
        Length[clauses] == 1,
        First[clauses],
        StringRiffle["(" <> # <> ")" & /@ clauses, " && "]
    ];
    {
        "((" <> StringRiffle[names, ", "] <> ") -> begin " <>
            $structuralEqualityRuntimeCode <> body <> " end)(" <>
            StringRiffle[renderHeld /@ items, ", "] <> ")",
        $precedenceCall
    }
];

emitHeld[HoldComplete[And[items___]]] :=
    emitLogical["&&", $precedenceAnd, heldItems[HoldComplete[items]]];
emitHeld[HoldComplete[Or[items___]]] :=
    emitLogical["||", $precedenceOr, heldItems[HoldComplete[items]]];

emitLogical["&&", _, {}] := {"true", $precedenceAtom};
emitLogical["||", _, {}] := {"false", $precedenceAtom};
emitLogical[_, _, {item_HoldComplete}] := emitHeld[item];

emitLogical[operator_String, precedence_Integer, items_List] := {
    StringRiffle[renderHeldAt[#, precedence] & /@ items, " " <> operator <> " "],
    precedence
};

emitHeld[HoldComplete[Not[item_]]] := {
    "!" <> renderHeldAt[HoldComplete[item], $precedenceUnary],
    $precedenceUnary
};

emitHeld[HoldComplete[If[condition_, yes_]]] :=
    emitIf[
        HoldComplete[condition],
        HoldComplete[yes],
        HoldComplete[Null]
    ];

emitHeld[HoldComplete[If[condition_, yes_, no_]]] :=
    emitIf[
        HoldComplete[condition],
        HoldComplete[yes],
        HoldComplete[no]
    ];

emitIf[condition_HoldComplete, yes_HoldComplete, no_HoldComplete] := {
    renderHeldAt[condition, $precedenceTernary + 1] <>
        " ? " <> renderHeldAt[yes, $precedenceTernary] <>
        " : " <> renderHeldAt[no, $precedenceTernary],
    $precedenceTernary
};

emitHeld[HoldComplete[Piecewise[pieces_List]]] :=
    emitPiecewise[HoldComplete[pieces], HoldComplete[0]];

emitHeld[HoldComplete[Piecewise[pieces_List, default_]]] :=
    emitPiecewise[HoldComplete[pieces], HoldComplete[default]];

emitPiecewise[pieces_HoldComplete, default_HoldComplete] := Module[
    {entries, result, pair},
    entries = listItems[pieces];
    If[
        Not[AllTrue[
            entries,
            MatchQ[#, HoldComplete[List[_, _]]] &
        ]],
        failUnsupported["a malformed Piecewise expression"]
    ];
    result = renderHeldAt[default, $precedenceTernary];
    Do[
        pair = listItems[entry];
        result = renderHeldAt[pair[[2]], $precedenceTernary + 1] <>
            " ? " <> renderHeldAt[pair[[1]], $precedenceTernary] <>
            " : (" <> result <> ")",
        {entry, Reverse[entries]}
    ];
    {result, $precedenceTernary}
];

emitHeld[HoldComplete[Rule[left_, right_]]] := {
    renderHeldAt[HoldComplete[left], $precedencePair + 1] <>
        " => " <>
        renderHeldAt[HoldComplete[right], $precedencePair],
    $precedencePair
};

emitHeld[HoldComplete[RuleDelayed[_, _]]] :=
    failUnsupported["RuleDelayed"];

emitHeld[HoldComplete[Association[rules___]]] := Module[{items},
    items = heldItems[HoldComplete[rules]];
    If[
        Not[AllTrue[
            items,
            MatchQ[#, HoldComplete[Rule[_, _]]] &
        ]],
        failUnsupported["a delayed or malformed Association"]
    ];
    {
        associationCode[items],
        $precedenceCall
    }
];

associationCode[items_List] :=
    "((__jf_pairs) -> begin " <>
        $structuralEqualityRuntimeCode <>
        $associationKeyGuardRuntimeCode <>
        "__jf_canonical = Pair[]; " <>
        "for __jf_pair in __jf_pairs; " <>
            "__jf_require_supported_association_key(first(__jf_pair)); " <>
            "__jf_position = findfirst(__jf_existing -> " <>
                "__jf_same(first(__jf_existing), first(__jf_pair)), " <>
                "__jf_canonical); " <>
            "if isnothing(__jf_position); " <>
                "push!(__jf_canonical, __jf_pair); " <>
            "else __jf_canonical[__jf_position] = " <>
                "first(__jf_canonical[__jf_position]) => " <>
                "last(__jf_pair); end; " <>
        "end; " <>
        "for __jf_right in 2:length(__jf_canonical), " <>
                "__jf_left in 1:(__jf_right - 1); " <>
            "__jf_left_key = first(__jf_canonical[__jf_left]); " <>
            "__jf_right_key = first(__jf_canonical[__jf_right]); " <>
            "if !__jf_same(__jf_left_key, __jf_right_key) && " <>
                    "isequal(__jf_left_key, __jf_right_key); " <>
                "throw(ArgumentError(\"Association keys cannot be " <>
                    "materialized as a Julia Dict without merging " <>
                    "distinct Wolfram keys\")); end; " <>
        "end; Dict(__jf_canonical) end)(" <>
        juliaTupleCode[renderHeld /@ items] <> ")";

listItems[HoldComplete[List[items___]]] := heldItems[HoldComplete[items]];

listExpressionQ[HoldComplete[List[___]]] := True;
listExpressionQ[_] := False;

containsLiteralListQ[held_HoldComplete] :=
    Not[FreeQ[held, _List, Infinity]];

matrixEntryCode[held_HoldComplete] := Module[{emitted},
    emitted = emitHeld[held];
    If[
        emitted[[2]] < $precedenceCall,
        "(" <> emitted[[1]] <> ")",
        emitted[[1]]
    ]
];

emitHeld[HoldComplete[List[items___]]] :=
    emitList[heldItems[HoldComplete[items]]];

emitList[{}] := {"[]", $precedenceAtom};

emitList[items_List] := Module[
    {rows, lengths, rowCount, columnCount, cells, code},
    If[AllTrue[items, listExpressionQ],
        rows = listItems /@ items;
        lengths = Length /@ rows;
        If[SameQ @@ lengths,
            rowCount = Length[rows];
            columnCount = First[lengths];
            cells = Flatten[rows, 1];
            If[AnyTrue[cells, listExpressionQ],
                failUnsupported["a rank-3 or higher List"]
            ];
            code = Which[
                columnCount == 0,
                    "Matrix{Any}(undef, " <>
                        ToString[rowCount, InputForm] <> ", 0)",
                columnCount == 1,
                    "[" <>
                        StringRiffle[
                            matrixEntryCode[First[#]] & /@ rows,
                            "; "
                        ] <>
                        ";;]",
                True,
                    "[" <>
                        StringRiffle[
                            StringRiffle[matrixEntryCode /@ #, " "] & /@ rows,
                            "; "
                        ] <>
                        "]"
            ];
            Return[{code, $precedenceAtom}]
        ]
    ];
    {
        "[" <> StringRiffle[renderHeld /@ items, ", "] <> "]",
        $precedenceAtom
    }
];

emitHeld[HoldComplete[Part[expression_, indices___]]] := Module[{items},
    items = heldItems[HoldComplete[indices]];
    If[items === {}, failUnsupported["Part without an index"]];
    {
        partCode[HoldComplete[expression], items],
        $precedenceCall
    }
];

juliaTupleCode[{}] := "()";
juliaTupleCode[items_List] :=
    "(" <> StringRiffle[items, ", "] <>
        If[Length[items] == 1, ",", ""] <> ")";

(* Build literal Lists and Associations inside the generated lambda while
   evaluating all non-container leaves as lambda arguments. This gives every
   Association in one Part expression the same unforgeable identity token. *)
partValuePlan[expression_HoldComplete] := Module[
    {
        leaves = {},
        build,
        buildList,
        buildMatrixEntry,
        buildAssociationPair,
        template
    },
    buildList[{}] := "__jf_literal_array(Any[])";
    buildList[items_List] := Module[
        {rows, lengths, rowCount, columnCount, cells, code},
        If[AllTrue[items, listExpressionQ],
            rows = listItems /@ items;
            lengths = Length /@ rows;
            If[SameQ @@ lengths,
                rowCount = Length[rows];
                columnCount = First[lengths];
                cells = Flatten[rows, 1];
                If[AnyTrue[cells, listExpressionQ],
                    failUnsupported["a rank-3 or higher List"]
                ];
                code = Which[
                    columnCount == 0,
                        "Matrix{Any}(undef, " <>
                            ToString[rowCount, InputForm] <> ", 0)",
                    columnCount == 1,
                        "Any[" <>
                            StringRiffle[
                                buildMatrixEntry[First[#]] & /@ rows,
                                "; "
                            ] <>
                            ";;]",
                    True,
                        "Any[" <>
                            StringRiffle[
                                StringRiffle[
                                    buildMatrixEntry /@ #,
                                    " "
                                ] & /@ rows,
                                "; "
                            ] <>
                            "]"
                ];
                Return["__jf_literal_array(" <> code <> ")"]
            ]
        ];
        "__jf_literal_array(Any[" <>
            StringRiffle[build /@ items, ", "] <> "])"
    ];
    buildMatrixEntry[held_HoldComplete] :=
        "(" <> build[held] <> ")";
    buildAssociationPair[HoldComplete[Rule[key_, value_]]] :=
        build[HoldComplete[key]] <> " => " <>
            build[HoldComplete[value]];
    build[HoldComplete[List[items___]]] :=
        buildList[heldItems[HoldComplete[items]]];
    build[HoldComplete[Association[rules___]]] := Module[
        {items, pairs},
        items = heldItems[HoldComplete[rules]];
        If[
            Not[AllTrue[items, MatchQ[#, HoldComplete[Rule[_, _]]] &]],
            failUnsupported["a delayed or malformed Association in Part"]
        ];
        pairs = buildAssociationPair /@ items;
        "(__jf_token, " <> juliaTupleCode[pairs] <> ")"
    ];
    build[held_HoldComplete] := Module[{name},
        AppendTo[leaves, renderHeld[held]];
        name = "__jf_leaf" <> ToString[Length[leaves], InputForm];
        name
    ];
    template = build[expression];
    {template, leaves}
];

partSpecCode[HoldComplete[All]] := "(:all,)";
partSpecCode[HoldComplete[0]] := failUnsupported["Part index 0"];
partSpecCode[HoldComplete[Key[key_]]] :=
    "(:key, " <> renderHeld[HoldComplete[key]] <> ")";
partSpecCode[HoldComplete[Span[start_, stop_]]] :=
    "(:span, " <> partEndpointCode[HoldComplete[start], First] <> ", " <>
        partEndpointCode[HoldComplete[stop], Last] <> ", 1)";
partSpecCode[HoldComplete[Span[_, _, 0]]] :=
    failUnsupported["a Span with step 0"];
partSpecCode[HoldComplete[Span[start_, stop_, step_]]] :=
    "(:span, " <> partEndpointCode[HoldComplete[start], First] <> ", " <>
        partEndpointCode[HoldComplete[stop], Last] <> ", " <>
        renderHeld[HoldComplete[step]] <> ")";
partSpecCode[HoldComplete[Span[___]]] :=
    failUnsupported["a malformed Span index"];
partSpecCode[HoldComplete[UpTo[___]]] :=
    failUnsupported["UpTo as a Part index"];
partSpecCode[HoldComplete[List[items___]]] :=
    "(:list, " <>
        juliaTupleCode[partSpecCode /@ heldItems[HoldComplete[items]]] <>
        ")";
partSpecCode[held_HoldComplete] :=
    "(:index, " <> renderHeld[held] <> ")";

partEndpointCode[HoldComplete[All], First] := ":first";
partEndpointCode[HoldComplete[All], Last] := ":last";
partEndpointCode[HoldComplete[UpTo[___]], _] :=
    failUnsupported["UpTo as a Span endpoint"];
partEndpointCode[held_HoldComplete, _] := renderHeld[held];

(* This self-contained Julia runtime distinguishes multidimensional arrays
   from nested vectors and never assumes that an array axis starts at one. *)
$partRuntimeCode = StringJoin[
    "__jf_is_marker = (__jf_item) -> ",
        "__jf_item isa Tuple && length(__jf_item) == 2 && ",
        "__jf_item[1] === __jf_token && ",
        "__jf_item[2] isa Tuple; ",
    $structuralEqualityRuntimeCode,
    "__jf_key_equal = __jf_same; ",
    "__jf_key_has_unsupported_container = nothing; ",
    "__jf_key_has_unsupported_container = function (__jf_key) ",
        "if __jf_is_marker(__jf_key) || __jf_key isa AbstractArray || ",
                "__jf_key isa AbstractDict; ",
            "return true; ",
        "elseif __jf_key isa Pair; ",
            "return __jf_key_has_unsupported_container(first(__jf_key)) || ",
                "__jf_key_has_unsupported_container(last(__jf_key)); ",
        "elseif __jf_key isa Tuple; ",
            "return any(__jf_key_has_unsupported_container, __jf_key); ",
        "end; false end; ",
    "__jf_require_supported_association_key = (__jf_key) -> ",
        "(__jf_key_has_unsupported_container(__jf_key) && ",
            "throw(ArgumentError(\"container-valued Association keys ",
                "cannot be represented faithfully as Julia Dict keys\")); ",
        "__jf_key); ",
    "__jf_canonical_pairs = function (__jf_pairs) ",
        "__jf_result = Pair[]; ",
        "for __jf_pair in __jf_pairs; ",
            "__jf_require_supported_association_key(first(__jf_pair)); ",
            "__jf_position = findfirst(__jf_existing -> ",
                "__jf_key_equal(first(__jf_existing), first(__jf_pair)), ",
                "__jf_result); ",
            "if isnothing(__jf_position); push!(__jf_result, __jf_pair); ",
            "else __jf_result[__jf_position] = ",
                "first(__jf_result[__jf_position]) => last(__jf_pair); end; ",
        "end; Tuple(__jf_result) end; ",
    "__jf_dict_safe = function (__jf_pairs) ",
        "for __jf_right in 2:length(__jf_pairs), ",
                "__jf_left in 1:(__jf_right - 1); ",
            "__jf_left_key = first(__jf_pairs[__jf_left]); ",
            "__jf_right_key = first(__jf_pairs[__jf_right]); ",
            "if !__jf_key_equal(__jf_left_key, __jf_right_key) && ",
                    "isequal(__jf_left_key, __jf_right_key); ",
                "return false; end; ",
        "end; true end; ",
    "__jf_runtime_dict_pairs = function (__jf_dict) ",
        "__jf_pairs = Tuple(pairs(__jf_dict)); ",
        "for __jf_pair in __jf_pairs; ",
            "__jf_require_supported_association_key(first(__jf_pair)); ",
        "end; ",
        "for __jf_right in 2:length(__jf_pairs), ",
                "__jf_left in 1:(__jf_right - 1); ",
            "if __jf_key_equal(first(__jf_pairs[__jf_left]), ",
                    "first(__jf_pairs[__jf_right])); ",
                "throw(ArgumentError(\"runtime Dict contains keys that ",
                    "are ambiguous under Wolfram Association semantics\")); ",
            "end; ",
        "end; __jf_pairs end; ",
    "__jf_require_dict_safe = function (__jf_pairs) ",
        "__jf_dict_safe(__jf_pairs) || throw(ArgumentError(",
            "\"Association keys cannot be materialized as a Julia Dict ",
                "without merging distinct Wolfram keys\")); ",
        "__jf_pairs end; ",
    "__jf_materialize = nothing; ",
    "__jf_materialize = function (__jf_item) ",
        "if __jf_is_marker(__jf_item); ",
            "__jf_pairs = __jf_require_dict_safe(",
                "__jf_canonical_pairs(__jf_item[2])); ",
            "return Dict(first(__jf_pair) => ",
                "__jf_materialize(last(__jf_pair)) for ",
                "__jf_pair in __jf_pairs); ",
        "elseif __jf_item isa AbstractArray && ",
                "haskey(__jf_literal_arrays, __jf_item); ",
            "return map(__jf_materialize, __jf_item); ",
        "end; __jf_item end; ",
    "__jf_normalize = function (__jf_index, __jf_axis) ",
        "__jf_index isa Integer && !(__jf_index isa Bool) || ",
            "throw(ArgumentError(",
            "\"Part indices must be integers\")); ",
        "__jf_index == 0 && throw(ArgumentError(\"Part index 0\")); ",
        "__jf_position = __jf_index < 0 ? ",
            "length(__jf_axis) + __jf_index + 1 : __jf_index; ",
        "1 <= __jf_position <= length(__jf_axis) || ",
            "throw(BoundsError(__jf_axis, __jf_position)); ",
        "first(__jf_axis) + __jf_position - 1 end; ",
    "__jf_endpoint_position = function (",
            "__jf_endpoint, __jf_axis, __jf_role, __jf_step) ",
        "__jf_length = length(__jf_axis); ",
        "if __jf_endpoint === :first; __jf_position = 1; ",
        "elseif __jf_endpoint === :last; __jf_position = __jf_length; ",
        "else ",
            "__jf_endpoint isa Integer && !(__jf_endpoint isa Bool) || ",
                "throw(ArgumentError(\"Span endpoints must be integers\")); ",
            "__jf_position = __jf_endpoint < 0 ? ",
                "__jf_length + __jf_endpoint + 1 : __jf_endpoint; ",
        "end; ",
        "__jf_valid = if __jf_step > 0; ",
            "__jf_role === :start ? ",
                "(1 <= __jf_position <= __jf_length + 1 || ",
                    "(__jf_length == 0 && __jf_endpoint == 0)) : ",
                "0 <= __jf_position <= __jf_length; ",
        "else __jf_role === :start ? ",
                "1 <= __jf_position <= __jf_length : ",
                "1 <= __jf_position <= __jf_length + 1; end; ",
        "__jf_valid || throw(BoundsError(__jf_axis, __jf_position)); ",
        "__jf_position end; ",
    "__jf_axis_label = (__jf_position, __jf_axis) -> ",
        "first(__jf_axis) + __jf_position - 1; ",
    "__jf_to_index = nothing; ",
    "__jf_to_index = function (__jf_spec, __jf_axis) ",
        "__jf_tag = __jf_spec[1]; ",
        "if __jf_tag === :all; return collect(__jf_axis); ",
        "elseif __jf_tag === :index; ",
            "return __jf_normalize(__jf_spec[2], __jf_axis); ",
        "elseif __jf_tag === :span; ",
            "__jf_step = __jf_spec[4]; ",
            "__jf_step isa Integer && !(__jf_step isa Bool) || ",
                "throw(ArgumentError(\"Span step must be an integer\")); ",
            "__jf_step == 0 && throw(ArgumentError(",
                "\"Span step cannot be 0\")); ",
            "__jf_start_position = __jf_endpoint_position(",
                "__jf_spec[2], __jf_axis, :start, __jf_step); ",
            "__jf_stop_position = __jf_endpoint_position(",
                "__jf_spec[3], __jf_axis, :stop, __jf_step); ",
            "((__jf_step > 0 && ",
                    "__jf_start_position <= __jf_stop_position + 1) || ",
                "(__jf_step < 0 && ",
                    "__jf_start_position >= __jf_stop_position - 1)) || ",
                "throw(ArgumentError(",
                    "\"Span step points away from its endpoint\")); ",
            "isempty(__jf_axis) && return collect(__jf_axis); ",
            "__jf_start = __jf_axis_label(",
                "__jf_start_position, __jf_axis); ",
            "__jf_stop = __jf_axis_label(",
                "__jf_stop_position, __jf_axis); ",
            "return collect(__jf_start:__jf_step:__jf_stop); ",
        "elseif __jf_tag === :list; ",
            "all(__jf_item -> __jf_item[1] === :index, ",
                "__jf_spec[2]) || throw(ArgumentError(",
                    "\"array index lists must contain scalar indices\")); ",
            "return [__jf_to_index(__jf_item, __jf_axis) for ",
                "__jf_item in __jf_spec[2]]; ",
        "end; throw(ArgumentError(\"Key is only valid for a Dict\")) end; ",
    "__jf_pair_for = function (__jf_spec, __jf_pairs) ",
        "__jf_tag = __jf_spec[1]; ",
        "if __jf_tag === :key; ",
            "__jf_position = findfirst(__jf_pair -> ",
                "__jf_key_equal(first(__jf_pair), __jf_spec[2]), ",
                "__jf_pairs); ",
            "isnothing(__jf_position) && ",
                "return __jf_spec[2] => missing; ",
            "return __jf_pairs[__jf_position]; ",
        "elseif __jf_tag === :index; ",
            "return __jf_pairs[__jf_normalize(",
                "__jf_spec[2], Base.OneTo(length(__jf_pairs)))]; ",
        "end; throw(ArgumentError(\"invalid scalar Association index\")) ",
        "end; ",
    "__jf_array_extract = function (__jf_array, __jf_specs, __jf_count) ",
        "__jf_dimensions = ndims(__jf_array); ",
        "__jf_indices = ntuple(__jf_dimension -> ",
            "__jf_dimension <= __jf_count ? ",
                "__jf_to_index(__jf_specs[__jf_dimension], ",
                    "axes(__jf_array, __jf_dimension)) : ",
                "collect(axes(__jf_array, __jf_dimension)), ",
            "__jf_dimensions); ",
        "__jf_scalar = ntuple(__jf_dimension -> ",
            "__jf_dimension <= __jf_count && ",
                "__jf_specs[__jf_dimension][1] === :index, ",
            "__jf_dimensions); ",
        "all(__jf_scalar) && return getindex(__jf_array, __jf_indices...); ",
        "__jf_iterators = ntuple(__jf_dimension -> ",
            "__jf_scalar[__jf_dimension] ? ",
                "(__jf_indices[__jf_dimension],) : ",
                "__jf_indices[__jf_dimension], __jf_dimensions); ",
        "__jf_values = [getindex(__jf_array, __jf_index...) for ",
            "__jf_index in Iterators.product(__jf_iterators...)]; ",
        "__jf_shape = Tuple(length(__jf_indices[__jf_dimension]) for ",
            "__jf_dimension in 1:__jf_dimensions if ",
                "!__jf_scalar[__jf_dimension]); ",
        "__jf_result = reshape(vec(__jf_values), __jf_shape); ",
        "haskey(__jf_literal_arrays, __jf_array) ? ",
            "__jf_literal_array(__jf_result) : __jf_result end; ",
    "__jf_part = nothing; ",
    "__jf_part = function (__jf_current, __jf_rest) ",
        "__jf_current === missing && return missing; ",
        "isempty(__jf_rest) && return __jf_materialize(__jf_current); ",
        "__jf_spec = first(__jf_rest); ",
        "__jf_tail = Base.tail(__jf_rest); ",
        "__jf_marker = __jf_is_marker(__jf_current); ",
        "if __jf_marker || __jf_current isa AbstractDict; ",
            "if !__jf_marker && __jf_spec[1] !== :key; ",
                "throw(ArgumentError(\"positional Part on an arbitrary ",
                    "Dict is unsupported\")); end; ",
            "__jf_pairs = __jf_marker ? ",
                "__jf_canonical_pairs(__jf_current[2]) : ",
                "__jf_runtime_dict_pairs(__jf_current); ",
            "if __jf_spec[1] === :key || __jf_spec[1] === :index; ",
                "__jf_pair = __jf_pair_for(__jf_spec, __jf_pairs); ",
                "return __jf_part(last(__jf_pair), __jf_tail); ",
            "elseif __jf_spec[1] === :all; ",
                "__jf_selected = __jf_pairs; ",
            "elseif __jf_spec[1] === :span; ",
                "__jf_selected = __jf_pairs[__jf_to_index(",
                    "__jf_spec, Base.OneTo(length(__jf_pairs)))]; ",
            "elseif __jf_spec[1] === :list; ",
                "__jf_selected = [__jf_pair_for(__jf_item, __jf_pairs) for ",
                    "__jf_item in __jf_spec[2]]; ",
            "else throw(ArgumentError(\"invalid Association index\")); end; ",
            "__jf_selected = __jf_require_dict_safe(",
                "__jf_canonical_pairs(__jf_selected)); ",
            "return Dict(first(__jf_pair) => ",
                "__jf_part(last(__jf_pair), __jf_tail) for ",
                "__jf_pair in __jf_selected); ",
        "elseif __jf_current isa AbstractArray; ",
            "ndims(__jf_current) == 0 && throw(ArgumentError(",
                "\"Part applied to a zero-dimensional array\")); ",
            "__jf_count = min(length(__jf_rest), ndims(__jf_current)); ",
            "__jf_result = __jf_array_extract(",
                "__jf_current, __jf_rest, __jf_count); ",
            "if length(__jf_rest) > __jf_count; ",
                "__jf_remaining = __jf_rest[__jf_count + 1:end]; ",
                "return all(__jf_item -> __jf_item[1] === :index, ",
                    "__jf_rest[1:__jf_count]) ? ",
                    "__jf_part(__jf_result, __jf_remaining) : ",
                    "map(__jf_item -> __jf_part(__jf_item, ",
                        "__jf_remaining), __jf_result); ",
            "end; return __jf_materialize(__jf_result); ",
        "end; throw(ArgumentError(",
            "\"Part applied below the available expression depth\")) end; ",
    "__jf_part(__jf_value, __jf_specs)"
];

partCode[expression_HoldComplete, items_List] := Module[
    {plan, leafNames, parameters, arguments},
    plan = partValuePlan[expression];
    leafNames = Table[
        "__jf_leaf" <> ToString[index, InputForm],
        {index, Length[plan[[2]]]}
    ];
    parameters = Append[leafNames, "__jf_specs"];
    arguments = Append[
        plan[[2]],
        juliaTupleCode[partSpecCode /@ items]
    ];
    "((" <> StringRiffle[parameters, ", "] <> ") -> begin " <>
        "__jf_token = Ref{Nothing}(); " <>
        "__jf_literal_arrays = IdDict{Any, Nothing}(); " <>
        "__jf_literal_array = (__jf_array) -> begin " <>
            "__jf_literal_arrays[__jf_array] = nothing; __jf_array end; " <>
        "__jf_value = " <> plan[[1]] <> "; " <>
        $partRuntimeCode <> " end)(" <>
        StringRiffle[arguments, ", "] <> ")"
];

emitHeld[HoldComplete[ArcTan[x_, y_]]] := Module[{items},
    items = {HoldComplete[x], HoldComplete[y]};
    If[
        AnyTrue[items, listExpressionQ],
        failUnsupported["a held Listable function applied to a literal List"]
    ];
    {
        "((__jf_x, __jf_y) -> atan(__jf_y, __jf_x))(" <>
            renderHeld[HoldComplete[x]] <> ", " <>
            renderHeld[HoldComplete[y]] <> ")",
        $precedenceCall
    }
];

emitHeld[HoldComplete[Sinc[x_]]] := Module[{},
    If[
        listExpressionQ[HoldComplete[x]],
        failUnsupported["a held Listable function applied to a literal List"]
    ];
    {
        "sinc(" <>
            renderHeldAt[HoldComplete[x], $precedenceMultiplicative] <>
            " / pi)",
        $precedenceCall
    }
];

emitHeld[HoldComplete[Quotient[x_, y_]]] := Module[{items},
    items = {HoldComplete[x], HoldComplete[y]};
    If[
        AnyTrue[items, listExpressionQ],
        failUnsupported["a held Listable function applied to a literal List"]
    ];
    {
        "fld(" <> renderHeld[HoldComplete[x]] <> ", " <>
            renderHeld[HoldComplete[y]] <> ")",
        $precedenceCall
    }
];

emitHeld[HoldComplete[Min[]]] := {"Inf", $precedenceAtom};
emitHeld[HoldComplete[Max[]]] := {"-Inf", $precedenceUnary};
emitHeld[HoldComplete[GCD[]]] := {"0", $precedenceAtom};

emitHeld[HoldComplete[Eigenvalues[___]]] :=
    failUnsupported[
        "Eigenvalues because Julia eigvals does not preserve Wolfram ordering"
    ];

emitHeld[HoldComplete[Sinc[___]]] :=
    failUnsupported["an unsupported arity of Sinc"];
emitHeld[HoldComplete[Quotient[___]]] :=
    failUnsupported["an unsupported arity of Quotient"];

emitHeld[HoldComplete[head_[arguments___]]] /;
        mappedFunctionHeadQ[HoldComplete[head]] &&
        Not[mappedFunctionArityQ[
            HoldComplete[head],
            Length[heldItems[HoldComplete[arguments]]]
        ]] :=
    failUnsupported[
        "an unsupported arity of " <> heldHeadName[HoldComplete[head]]
    ];

emitHeld[HoldComplete[Hold[___]]] := failUnsupported["Hold"];
emitHeld[HoldComplete[HoldComplete[___]]] := failUnsupported["HoldComplete"];
emitHeld[HoldComplete[RuleDelayed[___]]] := failUnsupported["RuleDelayed"];
emitHeld[HoldComplete[SparseArray[___]]] := failUnsupported["SparseArray"];
emitHeld[HoldComplete[Root[___]]] := failUnsupported["Root"];
emitHeld[HoldComplete[Quantity[___]]] := failUnsupported["Quantity"];
emitHeld[HoldComplete[Set[___]]] := failUnsupported["Set"];
emitHeld[HoldComplete[SetDelayed[___]]] := failUnsupported["SetDelayed"];
emitHeld[HoldComplete[Unset[___]]] := failUnsupported["Unset"];
emitHeld[HoldComplete[UpSet[___]]] := failUnsupported["UpSet"];
emitHeld[HoldComplete[UpSetDelayed[___]]] := failUnsupported["UpSetDelayed"];
emitHeld[HoldComplete[TagSet[___]]] := failUnsupported["TagSet"];
emitHeld[HoldComplete[TagSetDelayed[___]]] :=
    failUnsupported["TagSetDelayed"];
emitHeld[HoldComplete[TagUnset[___]]] := failUnsupported["TagUnset"];
emitHeld[HoldComplete[AddTo[___]]] := failUnsupported["AddTo"];
emitHeld[HoldComplete[AppendTo[___]]] := failUnsupported["AppendTo"];
emitHeld[HoldComplete[PrependTo[___]]] := failUnsupported["PrependTo"];
emitHeld[HoldComplete[AssociateTo[___]]] := failUnsupported["AssociateTo"];
emitHeld[HoldComplete[KeyDropFrom[___]]] := failUnsupported["KeyDropFrom"];
emitHeld[HoldComplete[SubtractFrom[___]]] :=
    failUnsupported["SubtractFrom"];
emitHeld[HoldComplete[TimesBy[___]]] := failUnsupported["TimesBy"];
emitHeld[HoldComplete[DivideBy[___]]] := failUnsupported["DivideBy"];
emitHeld[HoldComplete[Increment[___]]] := failUnsupported["Increment"];
emitHeld[HoldComplete[Decrement[___]]] := failUnsupported["Decrement"];
emitHeld[HoldComplete[PreIncrement[___]]] :=
    failUnsupported["PreIncrement"];
emitHeld[HoldComplete[PreDecrement[___]]] :=
    failUnsupported["PreDecrement"];
emitHeld[HoldComplete[CompoundExpression[___]]] :=
    failUnsupported["CompoundExpression"];
emitHeld[HoldComplete[Return[___]]] := failUnsupported["Return"];
emitHeld[HoldComplete[Throw[___]]] := failUnsupported["Throw"];
emitHeld[HoldComplete[Catch[___]]] := failUnsupported["Catch"];
emitHeld[HoldComplete[Do[___]]] := failUnsupported["Do"];
emitHeld[HoldComplete[While[___]]] := failUnsupported["While"];
emitHeld[HoldComplete[For[___]]] := failUnsupported["For"];
emitHeld[HoldComplete[Table[___]]] := failUnsupported["Table"];
emitHeld[HoldComplete[Switch[___]]] := failUnsupported["Switch"];
emitHeld[HoldComplete[Which[___]]] := failUnsupported["Which"];
emitHeld[HoldComplete[Scan[___]]] := failUnsupported["Scan"];
emitHeld[HoldComplete[Break[___]]] := failUnsupported["Break"];
emitHeld[HoldComplete[Continue[___]]] := failUnsupported["Continue"];
emitHeld[HoldComplete[Function[___]]] := failUnsupported["Function"];
emitHeld[HoldComplete[Slot[___]]] := failUnsupported["Slot"];
emitHeld[HoldComplete[SlotSequence[___]]] := failUnsupported["SlotSequence"];
emitHeld[HoldComplete[_Pattern]] := failUnsupported["Pattern"];
emitHeld[HoldComplete[_Condition]] := failUnsupported["Condition"];
emitHeld[HoldComplete[_PatternTest]] := failUnsupported["PatternTest"];
emitHeld[HoldComplete[_Optional]] := failUnsupported["Optional"];
emitHeld[HoldComplete[_Alternatives]] := failUnsupported["Alternatives"];
emitHeld[HoldComplete[_Repeated]] := failUnsupported["Repeated"];
emitHeld[HoldComplete[_RepeatedNull]] := failUnsupported["RepeatedNull"];
emitHeld[HoldComplete[_Blank]] := failUnsupported["Blank"];
emitHeld[HoldComplete[_BlankSequence]] :=
    failUnsupported["BlankSequence"];
emitHeld[HoldComplete[_BlankNullSequence]] :=
    failUnsupported["BlankNullSequence"];
emitHeld[HoldComplete[_Verbatim]] := failUnsupported["Verbatim"];
emitHeld[HoldComplete[_HoldPattern]] := failUnsupported["HoldPattern"];
emitHeld[HoldComplete[OptionValue[___]]] := failUnsupported["OptionValue"];
emitHeld[HoldComplete[Module[___]]] := failUnsupported["Module"];
emitHeld[HoldComplete[Block[___]]] := failUnsupported["Block"];
emitHeld[HoldComplete[With[___]]] := failUnsupported["With"];
emitHeld[HoldComplete[Defer[___]]] := failUnsupported["Defer"];
emitHeld[HoldComplete[ReleaseHold[___]]] := failUnsupported["ReleaseHold"];
emitHeld[HoldComplete[Evaluate[___]]] := failUnsupported["Evaluate"];
emitHeld[HoldComplete[Inactive[___]]] := failUnsupported["Inactive"];
emitHeld[HoldComplete[Activate[___]]] := failUnsupported["Activate"];
emitHeld[HoldComplete[Unevaluated[___]]] :=
    failUnsupported["Unevaluated"];
emitHeld[HoldComplete[Sequence[___]]] := failUnsupported["Sequence"];
emitHeld[HoldComplete[SetOptions[___]]] := failUnsupported["SetOptions"];
emitHeld[HoldComplete[SetAttributes[___]]] :=
    failUnsupported["SetAttributes"];
emitHeld[HoldComplete[ClearAttributes[___]]] :=
    failUnsupported["ClearAttributes"];
emitHeld[HoldComplete[Protect[___]]] := failUnsupported["Protect"];
emitHeld[HoldComplete[Unprotect[___]]] := failUnsupported["Unprotect"];
emitHeld[HoldComplete[Clear[___]]] := failUnsupported["Clear"];
emitHeld[HoldComplete[ClearAll[___]]] := failUnsupported["ClearAll"];
emitHeld[HoldComplete[Remove[___]]] := failUnsupported["Remove"];
emitHeld[HoldComplete[RowBox[___]]] := failUnsupported["RowBox"];
emitHeld[HoldComplete[StyleBox[___]]] := failUnsupported["StyleBox"];
emitHeld[HoldComplete[FormBox[___]]] := failUnsupported["FormBox"];
emitHeld[HoldComplete[InterpretationBox[___]]] :=
    failUnsupported["InterpretationBox"];

$dedicatedFormHeads = {
    HoldComplete[DirectedInfinity], HoldComplete[HoldForm],
    HoldComplete[Power], HoldComplete[Less], HoldComplete[LessEqual],
    HoldComplete[Greater], HoldComplete[GreaterEqual], HoldComplete[Equal],
    HoldComplete[Inequality], HoldComplete[Unequal], HoldComplete[SameQ],
    HoldComplete[UnsameQ], HoldComplete[And], HoldComplete[Or],
    HoldComplete[Not], HoldComplete[If], HoldComplete[Piecewise],
    HoldComplete[Rule], HoldComplete[Association], HoldComplete[List],
    HoldComplete[Part]
};

$forbiddenFallbackHeads = {
    HoldComplete[OptionsPattern], HoldComplete[PatternSequence],
    HoldComplete[Except], HoldComplete[Longest], HoldComplete[Shortest],
    HoldComplete[OrderlessPatternSequence], HoldComplete[KeyValuePattern]
};

dedicatedFormHeadQ[head_HoldComplete] :=
    MemberQ[$dedicatedFormHeads, head];
dedicatedFormHeadQ[_] := False;

$unsafeFallbackAttributes = {
    HoldAll, HoldAllComplete, HoldFirst, HoldRest, SequenceHold, NHoldAll
};

unsafeFallbackHeadQ[HoldComplete[symbol_Symbol]] := Module[{attributes},
    attributes = Attributes[Unevaluated[symbol]];
    AnyTrue[$unsafeFallbackAttributes, MemberQ[attributes, #] &]
];
unsafeFallbackHeadQ[_] := False;

forbiddenFallbackHeadQ[head_HoldComplete] :=
    MemberQ[$forbiddenFallbackHeads, head];
forbiddenFallbackHeadQ[_] := False;

listableHeadQ[HoldComplete[symbol_Symbol]] :=
    MemberQ[Attributes[Unevaluated[symbol]], Listable];
listableHeadQ[_] := False;

scalarListCallQ[head_HoldComplete] :=
    listableHeadQ[head] ||
        MemberQ[{HoldComplete[Min], HoldComplete[Max]}, head];

emitHeld[HoldComplete[head_[arguments___]]] /;
        scalarListCallQ[HoldComplete[head]] &&
        AnyTrue[heldItems[HoldComplete[arguments]], listExpressionQ] :=
    failUnsupported["a held Listable function applied to a literal List"];

emitHeld[HoldComplete[head_[___]]] /;
        dedicatedFormHeadQ[HoldComplete[head]] :=
    failUnsupported[
        "an unsupported form or arity of " <>
            heldHeadName[HoldComplete[head]]
    ];

emitHeld[HoldComplete[head_[___]]] /;
        unsafeFallbackHeadQ[HoldComplete[head]] :=
    failUnsupported[
        "a held or stateful call to " <> heldHeadName[HoldComplete[head]]
    ];

emitHeld[HoldComplete[head_[___]]] /;
        forbiddenFallbackHeadQ[HoldComplete[head]] :=
    failUnsupported[heldHeadName[HoldComplete[head]]];

emitHeld[HoldComplete[head_[arguments___]]] := {
    functionCode[HoldComplete[head]] <>
        "(" <>
        StringRiffle[
            renderHeld /@ heldItems[HoldComplete[arguments]],
            ", "
        ] <>
        ")",
    $precedenceCall
};

emitHeld[held : HoldComplete[_Symbol]] :=
    {symbolCode[held], $precedenceAtom};

emitHeld[HoldComplete[_]] :=
    failUnsupported["an unsupported atomic expression"];

JuliaForm[] := (
    Message[JuliaForm::argx, 0];
    $Failed
);

JuliaForm[first_, second_, rest___] := (
    Message[JuliaForm::argx, 2 + Length[{rest}]];
    $Failed
);

Format[JuliaForm[expr_], OutputForm] := Module[{code},
    code = renderJulia[expr];
    If[StringQ[code], SequenceForm[code], $Failed]
];

JuliaForm /: MakeBoxes[
        JuliaForm[expr_],
        form : (StandardForm | TraditionalForm)
    ] := Module[{code},
    code = renderJulia[expr];
    If[
        StringQ[code],
        With[{display = ToBoxes[code, StandardForm]},
            InterpretationBox[
                display,
                expr,
                Editable -> True,
                AutoDelete -> True
            ]
        ],
        MakeBoxes[$Failed, form]
    ]
];

JuliaForm /: ToString[expr_, JuliaForm] := renderJulia[expr];

registerOutputForm[] := Module[{wasProtected},
    wasProtected = MemberQ[Attributes[$OutputForms], Protected];
    WithCleanup[
        If[wasProtected, Unprotect[$OutputForms]],
        If[FreeQ[$OutputForms, JuliaForm], AppendTo[$OutputForms, JuliaForm]],
        If[wasProtected, Protect[$OutputForms]]
    ]
];

registerOutputForm[];
