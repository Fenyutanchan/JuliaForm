#!/usr/bin/env wolframscript

testDirectory = DirectoryName[$InputFileName];
pacletDirectory = DirectoryName[testDirectory];

Needs["PacletTools`"];
PacletDirectoryLoad[pacletDirectory];
Needs["JuliaForm`"];

syntaxExpressions = {
    HoldForm[a/(b + c)],
    HoldForm[(a + b)/c],
    HoldForm[a - (b + c)],
    HoldForm[(a + b)^c],
    HoldForm[x < y <= z],
    HoldForm[a && (!b || c)],
    HoldForm[If[c, a + b, a b]],
    Sin[x] + Exp[y] + Log[z],
    ArcTan[x, y],
    Sinc[x],
    Quotient[x, y],
    {1, x, "a"},
    {{1, 2}, {3, 4}},
    {{1}, {2}},
    {{}, {}},
    <|"x" -> 1, "y" -> {2, 3}|>,
    HoldForm[v[[2 ;; -1]]],
    HoldForm[m[[-1, All]]],
    HoldForm[v[[All ;; All]]],
    HoldForm[r[[All, 1]]],
    HoldForm[a[[Key["x"], 1]]],
    HoldForm[tensor3[[2, All]]],
    HoldForm[Unequal[f[], g[], h[]]],
    HoldForm[SameQ[f[], g[], h[]]],
    HoldForm[UnsameQ[f[], g[], h[]]],
    HoldForm[Log[b, x]],
    HoldForm[Mod[x, y]],
    f[x, y],
    foo`x,
    Symbol["a$b"],
    Symbol["public"]
};

syntaxSources =
    ToString[JuliaForm`JuliaForm[#], OutputForm] & /@ syntaxExpressions;

evaluationExpressions = {
    1/3,
    Complex[1/2, 2/3],
    2^100,
    1.25`30,
    "a\n\"b\\c$",
    {1, 2, 3},
    {{1, 2}, {3, 4}},
    {{1}, {2}},
    <|"x" -> 1, "y" -> {2, 3}|>,
    HoldForm[If[1 < 2, 3, 4]],
    HoldForm[Piecewise[{{10, 1 < 0}, {20, 1 < 2}}, 30]],
    "x" -> {1, 2},
    1.25`30*^100,
    E,
    HoldForm[(1 + 2)/3],
    HoldForm[10 - (2 + 3)],
    HoldForm[Part[{1, 2, 3}, 2]],
    HoldForm[Part[{{1, 2}, {3, 4}}, 2]],
    HoldForm[SameQ[1, 1]],
    HoldForm[SameQ[1, 1.]],
    HoldForm[UnsameQ[1, 1.]],
    HoldForm[Equal[]],
    HoldForm[Equal[jfUnaryProbe[1, 10]]],
    HoldForm[Unequal[]],
    HoldForm[Unequal[jfUnaryProbe[2, 20]]],
    HoldForm[And[]],
    HoldForm[Or[]],
    HoldForm[Part[{1, 2, 3}, All ;; All]],
    HoldForm[Part[{{1, 2}, {3}}, 2, 1]],
    HoldForm[Part[{{1, 2}, {3}}, All, 1]],
    HoldForm[Part[{{{1}, 2}, {{3}, 4, 5}}, All, 1, 1]],
    HoldForm[
        Part[<|"x" -> {10, 11}, "y" -> {20, 21}|>, 2, 1]
    ],
    HoldForm[
        Part[<|"x" -> {10, 11}, "y" -> {20, 21}|>, All, 1]
    ],
    HoldForm[
        Part[<|"x" -> {10, 11}, "y" -> {20, 21}|>, Key["y"], -1]
    ],
    HoldForm[Part[tensor3, 2, All]],
    HoldForm[
        Unequal[jfProbe[1, 1], jfProbe[2, 1], jfProbe[3, 3]]
    ],
    HoldForm[
        SameQ[jfProbe[4, 1], jfProbe[5, 2], jfProbe[6, 1]]
    ],
    HoldForm[
        UnsameQ[jfProbe[7, 1], jfProbe[8, 1], jfProbe[9, 2]]
    ],
    HoldForm[Part[{1, 2, 3}, All ;; 2]],
    HoldForm[Part[{1, 2, 3}, 2 ;; All]],
    HoldForm[Part[runtimeDict, Key["y"]]],
    HoldForm[Part[{{1, 2}, {3, 4, 5}}, {2, 1}, 2]],
    HoldForm[Part[{{1, 2}, {3, 4, 5}}, -1, -1]],
    HoldForm[Part[tensor3, 2, 2]],
    HoldForm[
        Part[<|"x" -> {10, 11}, "y" -> {20, 21}|>, {2, 1}, 1]
    ],
    HoldForm[
        Part[<|"x" -> {10, 11}, "y" -> {20, 21}|>, 1 ;; 2, 2]
    ],
    HoldForm[Part[{<|"x" -> {1, 2}|>}, 1, 1, 2]],
    HoldForm[
        Part[{{<|"x" -> 1|>}, {<|"x" -> 2|>}}, All, 1, 1]
    ],
    HoldForm[Part[offsetVector, 1]],
    HoldForm[Part[offsetVector, -1]],
    HoldForm[Part[<|"x" -> 1, "y" -> 2, "x" -> 3|>, 1]],
    HoldForm[Part[<|1 -> 10, 1. -> 20|>, Key[1]]],
    HoldForm[Part[<|1 -> 10, 1. -> 20|>, Key[1.]]],
    HoldForm[Part[{<|"x" -> 1|>}, 1]],
    HoldForm[Part[{<|"x" -> 1|>}, All]],
    HoldForm[SameQ[jfUnaryProbe[3, 30]]],
    HoldForm[UnsameQ[jfUnaryProbe[4, 40]]],
    HoldForm[Less[jfUnaryProbe[5, 50]]],
    HoldForm[LessEqual[jfUnaryProbe[6, 60]]],
    HoldForm[Greater[jfUnaryProbe[7, 70]]],
    HoldForm[GreaterEqual[jfUnaryProbe[8, 80]]],
    HoldForm[Inequality[jfUnaryProbe[9, 90]]],
    HoldForm[SameQ[0., -0.]],
    HoldForm[UnsameQ[0., -0.]],
    HoldForm[SameQ[Complex[1., 0.], Complex[1., -0.]]],
    HoldForm[UnsameQ[Complex[1., 0.], Complex[1., -0.]]],
    HoldForm[SameQ[Indeterminate, Indeterminate]],
    HoldForm[Part[offsetVector, All]],
    HoldForm[Part[offsetMatrix, 1]],
    HoldForm[Part[offsetMatrix, All, 1]],
    HoldForm[
        Equal[
            jfEagerProbe[1, 1],
            jfEagerProbe[2, 2],
            jfEagerProbe[3, 3]
        ]
    ],
    HoldForm[
        Less[
            jfEagerProbe[4, 2],
            jfEagerProbe[5, 1],
            jfEagerProbe[6, 3]
        ]
    ],
    HoldForm[
        LessEqual[
            jfEagerProbe[7, 2],
            jfEagerProbe[8, 1],
            jfEagerProbe[9, 3]
        ]
    ],
    HoldForm[
        Greater[
            jfEagerProbe[10, 1],
            jfEagerProbe[11, 2],
            jfEagerProbe[12, 0]
        ]
    ],
    HoldForm[
        GreaterEqual[
            jfEagerProbe[13, 1],
            jfEagerProbe[14, 2],
            jfEagerProbe[15, 0]
        ]
    ],
    HoldForm[
        Inequality[
            jfEagerProbe[16, 2], Less,
            jfEagerProbe[17, 1], LessEqual,
            jfEagerProbe[18, 3]
        ]
    ],
    HoldForm[SameQ[runtimeZeroArray, runtimeNegativeZeroArray]],
    HoldForm[UnsameQ[runtimeZeroArray, runtimeNegativeZeroArray]],
    HoldForm[
        SameQ[runtimeComplexZeroArray, runtimeComplexNegativeZeroArray]
    ],
    HoldForm[
        UnsameQ[runtimeComplexZeroArray, runtimeComplexNegativeZeroArray]
    ],
    HoldForm[SameQ[runtimeZeroPair, runtimeNegativeZeroPair]],
    HoldForm[UnsameQ[runtimeZeroPair, runtimeNegativeZeroPair]],
    HoldForm[SameQ[runtimeZeroTuple, runtimeNegativeZeroTuple]],
    HoldForm[UnsameQ[runtimeZeroTuple, runtimeNegativeZeroTuple]],
    HoldForm[Association[1 -> 10, 1 -> 20, "x" -> 30]],
    HoldForm[
        Association[
            runtimeSignedZeroKey[1] -> 10,
            runtimeSignedZeroKey[2] -> 20
        ]
    ],
    HoldForm[
        Association[
            runtimeComplexSignedZeroKey[1] -> 10,
            runtimeComplexSignedZeroKey[2] -> 20
        ]
    ],
    HoldForm[Association[Indeterminate -> 10, Indeterminate -> 20]],
    HoldForm[Part[{1, 1.}, 1]],
    HoldForm[Part[{{1, 1.}, {2, 2.}}, 1, 1]],
    HoldForm[Part[{1, 2, 3}, Span[1, 0]]],
    HoldForm[Part[{1, 2, 3}, Span[2, 1]]],
    HoldForm[Part[{1, 2, 3}, Span[4, 3]]],
    HoldForm[Part[{1, 2, 3}, Span[4, All]]],
    HoldForm[Part[{1, 2, 3}, Span[All, 0]]],
    HoldForm[Part[{1, 2, 3}, Span[3, 4, -1]]],
    HoldForm[Part[emptyVector, Span[All, All]]],
    HoldForm[Part[emptyVector, Span[1, 0]]],
    HoldForm[Part[offsetVector, Span[4, 3]]],
    HoldForm[Part[offsetVector, Span[All, 0]]],
    HoldForm[Part[offsetVector, Span[3, 4, -1]]],
    HoldForm[Part[<|"x" -> 1|>, Key["z"]]],
    HoldForm[Part[<|"x" -> 1|>, Key["z"], 1]],
    HoldForm[Part[<|"x" -> 1|>, {Key["z"], Key["x"]}]],
    HoldForm[
        ArcTan[
            jfArcTanProbe[1, 1.],
            jfArcTanProbe[2, 1.]
        ]
    ],
    HoldForm[
        Times[
            jfTimesOrderProbe[1, 2.],
            Power[jfReciprocalProbe[2, 4.], -1],
            jfTimesOrderProbe[3, 3.]
        ]
    ],
    HoldForm[
        Part[
            Association[
                runtimeSignedZeroKey[1] -> 10,
                runtimeSignedZeroKey[2] -> 20
            ],
            Key[runtimeSignedZeroKey[1]]
        ]
    ],
    HoldForm[
        Part[
            Association[
                runtimeComplexSignedZeroKey[1] -> 10,
                runtimeComplexSignedZeroKey[2] -> 20
            ],
            Key[runtimeComplexSignedZeroKey[1]]
        ]
    ],
    HoldForm[
        Part[
            Association[
                runtimeSignedZeroKey[1] -> 10,
                runtimeSignedZeroKey[2] -> 20
            ],
            All
        ]
    ],
    HoldForm[Part[emptyOffsetVector, Span[All, All]]],
    HoldForm[Part[emptyOffsetVector, Span[1, 0]]],
    HoldForm[Part[{offsetVector}, 1]],
    HoldForm[Part[Association["x" -> offsetVector], Key["x"]]],
    HoldForm[Part[{offsetVector}, All]],
    HoldForm[Part[Association["x" -> offsetVector], All]],
    HoldForm[Equal[True, True]],
    HoldForm[Unequal[True, False]],
    HoldForm[Equal[Null, Null]],
    HoldForm[Unequal[Null, Null]],
    HoldForm[Equal["a", "a"]],
    HoldForm[Unequal["a", 1]],
    HoldForm[
        Times[
            Power[jfReciprocalProbe[4, 2.], -1],
            Power[jfReciprocalProbe[5, 4.], -1]
        ]
    ]
};

evaluationSources =
    ToString[JuliaForm`JuliaForm[#], OutputForm] & /@ evaluationExpressions;

errorExpressions = {
    HoldForm[Part[runtimeDict, 1]],
    HoldForm[Part[runtimeDict, All]],
    HoldForm[Part[runtimeTaggedTuple, 1]],
    HoldForm[Part[runtimeRefTaggedTuple, 1]],
    HoldForm[Part[{1, 2, 3}, Span[1, 3, -1]]],
    HoldForm[Part[{1, 2, 3}, Span[3, 1, 1]]],
    HoldForm[Part[<|1 -> 10, 1. -> 20|>, All]],
    HoldForm[Part[<|1 -> 10, 1. -> 20|>, 1 ;; 2]],
    HoldForm[Part[<|1 -> 10, 1. -> 20|>, {1, 2}]],
    HoldForm[Association[1 -> 10, 1. -> 20]],
    HoldForm[
        Association[
            runtimeAssociationKey[1] -> 10,
            runtimeAssociationKey[2] -> 20
        ]
    ],
    HoldForm[SameQ[runtimeDict, runtimeDict]],
    HoldForm[UnsameQ[runtimeDict, runtimeDict]],
    HoldForm[Association[{1, 1.} -> 10]],
    HoldForm[Association[Association["k" -> 1] -> 10]],
    HoldForm[Part[Association[{1, 1.} -> 10], All]],
    HoldForm[
        Part[Association[Association["k" -> 1] -> 10], All]
    ],
    HoldForm[Part[runtimeAmbiguousDict, Key[0.]]],
    HoldForm[Part[runtimeContainerKeyDict, Key[runtimeArrayKey]]],
    HoldForm[
        SameQ[
            Association["a" -> 1, "b" -> 2],
            Association["a" -> 1, "b" -> 2]
        ]
    ],
    HoldForm[
        UnsameQ[
            Association["a" -> 1, "b" -> 2],
            Association["b" -> 2, "a" -> 1]
        ]
    ],
    HoldForm[
        Equal[
            Association["a" -> 1, "b" -> 2],
            Association["a" -> 1, "b" -> 2]
        ]
    ],
    HoldForm[
        Unequal[
            Association["a" -> 1, "b" -> 2],
            Association["b" -> 2, "a" -> 1]
        ]
    ],
    HoldForm[Equal[1, 2, runtimeDict]],
    HoldForm[Unequal[1, 2, runtimeDict]],
    HoldForm[Inequality[runtimeDict, Equal, runtimeDict]],
    HoldForm[
        Equal[
            "x" -> Association["a" -> 1, "b" -> 2],
            "x" -> Association["b" -> 2, "a" -> 1]
        ]
    ],
    HoldForm[Equal[Indeterminate, Indeterminate]],
    HoldForm[Unequal[Indeterminate, Indeterminate]],
    HoldForm[Less[Indeterminate, 1]],
    HoldForm[LessEqual[Indeterminate, 1]],
    HoldForm[Greater[Indeterminate, 1]],
    HoldForm[GreaterEqual[Indeterminate, 1]],
    HoldForm[Inequality[1, Less, Indeterminate, Less, 2]],
    HoldForm[Equal[runtimeNaNArray, runtimeNaNArray]],
    HoldForm[Equal[runtimeComplexNaN, runtimeComplexNaN]],
    HoldForm[Equal[True, 1]],
    HoldForm[Unequal[False, 0]],
    HoldForm[Less[True, 2]],
    HoldForm[Less["a", "b"]],
    HoldForm[Equal[runtimeMissing, runtimeMissing]],
    HoldForm[Unequal[runtimeMissing, runtimeMissing]],
    HoldForm[Equal[Null, 0]],
    HoldForm[Unequal[Null, 0]],
    HoldForm[Less[runtimeOrderingArray, runtimeOrderingArray]],
    HoldForm[Less[Complex[1, 0], 2]],
    HoldForm[Inequality[True, Equal, 1]]
};

errorSources =
    ToString[JuliaForm`JuliaForm[#], OutputForm] & /@ errorExpressions;

encodeSource[source_String] :=
    BaseEncode[ByteArray[ToCharacterCode[source, "UTF-8"]]];

Scan[
    WriteString["stdout", "SYNTAX\t", encodeSource[#], "\n"] &,
    syntaxSources
];

Scan[
    WriteString["stdout", "VALUE\t", encodeSource[#], "\n"] &,
    evaluationSources
];

Scan[
    WriteString["stdout", "ERROR\t", encodeSource[#], "\n"] &,
    errorSources
];

Quit[];
