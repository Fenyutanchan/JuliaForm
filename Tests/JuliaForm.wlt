VerificationTest[
    Needs["JuliaForm`"],
    Null,
    TestID -> "load-package"
]

VerificationTest[
    Names["JuliaForm`*"],
    {"JuliaForm"},
    TestID -> "only-one-public-symbol"
]

VerificationTest[
    Context[JuliaForm],
    "JuliaForm`",
    TestID -> "public-context"
]

VerificationTest[
    MemberQ[Attributes[JuliaForm], Protected] && Options[JuliaForm] === {},
    True,
    TestID -> "form-contract"
]

VerificationTest[
    Attributes[JuliaForm],
    {Protected},
    TestID -> "no-extra-attributes"
]

VerificationTest[
    StringEndsQ[
        FindFile["JuliaForm`"],
        FileNameJoin[{"Kernel", "init.wl"}]
    ],
    True,
    TestID -> "spf-loader"
]

VerificationTest[
    Module[
        {
            root,
            paclet,
            documentationExtension,
            documentationOptions,
            documentationFiles,
            notebooks,
            cellIDs,
            cellStyles,
            inputBoxes,
            outputBoxes
        },
        root = DirectoryName[DirectoryName[FindFile["JuliaForm`"]]];
        paclet = SelectFirst[
            PacletFind["JuliaForm"],
            FileNameSplit[#["Location"]] === FileNameSplit[root] &,
            Missing["NotFound"]
        ];
        documentationExtension = If[
            MatchQ[paclet, _PacletObject],
            SelectFirst[
                paclet["Extensions"],
                MatchQ[#, {"Documentation", ___}] &,
                Missing["NotFound"]
            ],
            Missing["NotFound"]
        ];
        documentationOptions = If[
            MatchQ[documentationExtension, {"Documentation", ___}],
            Association[Cases[Rest[documentationExtension], _Rule]],
            <||>
        ];
        documentationFiles = FileNameJoin[{
            root,
            "Documentation",
            #,
            "ReferencePages",
            "Symbols",
            "JuliaForm.nb"
        }] & /@ {"English", "ChineseSimplified"};
        notebooks = If[
            AllTrue[documentationFiles, FileExistsQ],
            Get /@ documentationFiles,
            {$Failed, $Failed}
        ];
        cellIDs[notebook_] := Cases[
            notebook,
            Cell[___, CellID -> id_, ___] :> id,
            Infinity
        ];
        cellStyles[notebook_] := Cases[
            notebook,
            Cell[_, style_String, ___] :> style,
            Infinity
        ];
        inputBoxes[notebook_] := Cases[
            notebook,
            Cell[data_, "Input", ___] :> HoldComplete[data],
            Infinity
        ];
        outputBoxes[notebook_] := Cases[
            notebook,
            Cell[data_, "Output", ___] :> HoldComplete[data],
            Infinity
        ];
        MatchQ[paclet, _PacletObject] &&
            Lookup[
                documentationOptions,
                Language,
                Lookup[
                    documentationOptions,
                    "Language",
                    Missing["NotFound"]
                ]
            ] === All &&
            MatchQ[notebooks, {_Notebook, _Notebook}] &&
            AllTrue[
                notebooks,
                Cases[
                    #,
                    Cell[
                        "JuliaForm/ref/JuliaForm",
                        "Categorization",
                        ___
                    ],
                    Infinity
                ] =!= {} &
            ] &&
            SameQ @@ (cellIDs /@ notebooks) &&
            SameQ @@ (cellStyles /@ notebooks) &&
            SameQ @@ (inputBoxes /@ notebooks) &&
            SameQ @@ (outputBoxes /@ notebooks)
    ],
    True,
    TestID -> "bilingual-native-documentation-pages"
]

VerificationTest[
    Module[
        {
            root,
            pairs,
            texts,
            headingLevels,
            fencedBlocks,
            tableRowCount,
            listItemCount,
            pairParityQ
        },
        root = DirectoryName[DirectoryName[FindFile["JuliaForm`"]]];
        pairs = {
            {
                FileNameJoin[{root, "README.md"}],
                FileNameJoin[{root, "README_zh-CN.md"}]
            },
            {
                FileNameJoin[{root, "CONTRIBUTING.md"}],
                FileNameJoin[{root, "CONTRIBUTING_zh-CN.md"}]
            }
        };
        texts = Association[
            # -> If[FileExistsQ[#], Import[#, "Text"], $Failed] & /@
                Flatten[pairs]
        ];
        headingLevels[text_String] := StringLength /@ Flatten[
            StringCases[
                StringSplit[text, {"\r\n", "\n", "\r"}],
                RegularExpression["^(#{1,6}) "] -> "$1"
            ]
        ];
        fencedBlocks[text_String] := Module[
            {lines, collecting = False, current = {}, blocks = {}},
            lines = StringSplit[text, {"\r\n", "\n", "\r"}];
            Do[
                If[
                    collecting,
                    AppendTo[current, line];
                    If[
                        StringTrim[line] === "```",
                        AppendTo[blocks, StringRiffle[current, "\n"]];
                        collecting = False;
                        current = {}
                    ],
                    If[
                        StringStartsQ[StringTrim[line], "```"],
                        collecting = True;
                        current = {line}
                    ]
                ],
                {line, lines}
            ];
            If[collecting, $Failed, blocks]
        ];
        tableRowCount[text_String] := Count[
            StringSplit[text, {"\r\n", "\n", "\r"}],
            line_ /; StringStartsQ[StringTrim[line], "|"]
        ];
        listItemCount[text_String] := Count[
            StringSplit[text, {"\r\n", "\n", "\r"}],
            line_ /; StringMatchQ[
                line,
                RegularExpression["^\\s*(- |[0-9]+\\. ).*"]
            ]
        ];
        pairParityQ[{englishPath_, chinesePath_}] := Module[
            {english = texts[englishPath], chinese = texts[chinesePath]},
            StringQ[english] &&
                StringQ[chinese] &&
                headingLevels[english] === headingLevels[chinese] &&
                fencedBlocks[english] === fencedBlocks[chinese] &&
                tableRowCount[english] === tableRowCount[chinese] &&
                listItemCount[english] === listItemCount[chinese]
        ];
        AllTrue[pairs, pairParityQ] &&
            StringContainsQ[
                texts[FileNameJoin[{root, "README.md"}]],
                "canonical project README"
            ] &&
            StringContainsQ[
                texts[FileNameJoin[{root, "README_zh-CN.md"}]],
                "规范英文文档"
            ] &&
            StringContainsQ[
                texts[FileNameJoin[{root, "CONTRIBUTING.md"}]],
                "Edit the canonical English file first."
            ] &&
            StringContainsQ[
                texts[FileNameJoin[{root, "CONTRIBUTING_zh-CN.md"}]],
                "首先编辑规范英文文件"
            ]
    ],
    True,
    TestID -> "bilingual-markdown-documentation-parity"
]

VerificationTest[
    Count[$OutputForms, JuliaForm],
    1,
    TestID -> "output-form-registered-once"
]

VerificationTest[
    MemberQ[Attributes[$OutputForms], Protected] &&
        FreeQ[$PrintForms, JuliaForm] &&
        FreeQ[$BoxForms, JuliaForm],
    True,
    TestID -> "form-registration-is-scoped"
]

VerificationTest[
    ToString[JuliaForm[42], OutputForm],
    "42",
    TestID -> "integer"
]

VerificationTest[
    ToString[JuliaForm[1/3], OutputForm],
    "1 // 3",
    TestID -> "exact-rational"
]

VerificationTest[
    ToString[JuliaForm[1.], OutputForm],
    "1.0",
    TestID -> "machine-real"
]

VerificationTest[
    ToString[JuliaForm[1.25`30*^100], OutputForm],
    "BigFloat(\"1.25e100\"; precision = 100)",
    TestID -> "arbitrary-real-scientific-notation"
]

VerificationTest[
    ToString[JuliaForm[2^100], OutputForm],
    "big\"1267650600228229401496703205376\"",
    TestID -> "big-integer"
]

VerificationTest[
    ToString[JuliaForm[3 + 4 I], OutputForm],
    "Complex(3, 4)",
    TestID -> "complex"
]

VerificationTest[
    ToString[JuliaForm[Complex[1/2, 2/3]], OutputForm],
    "Complex(1 // 2, 2 // 3)",
    TestID -> "exact-complex"
]

VerificationTest[
    ToString[JuliaForm[{Pi, E, I, Infinity, -Infinity, Indeterminate}], OutputForm],
    "[pi, ℯ, im, Inf, -Inf, NaN]",
    TestID -> "constants"
]

VerificationTest[
    ToString[
        JuliaForm[HoldForm[(a + b) c]],
        OutputForm
    ],
    "(a + b) * c",
    TestID -> "multiplication-parentheses"
]

VerificationTest[
    ToString[
        JuliaForm[HoldForm[a/(b + c)]],
        OutputForm
    ],
    "a / (b + c)",
    TestID -> "division-parentheses"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[(a + b)/c]], OutputForm],
    "(a + b) / c",
    TestID -> "division-numerator-parentheses"
]

VerificationTest[
    ToString[
        JuliaForm[
            HoldForm[
                Times[u[], Power[v[], -1], w[]]
            ]
        ],
        OutputForm
    ],
    "((__jf_factor1, __jf_factor2, __jf_factor3) -> " <>
        "__jf_factor1 * __jf_factor2 * __jf_factor3)(" <>
        "u(), inv(v()), w())",
    TestID -> "reciprocal-regrouping-preserves-factor-evaluation-order"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[x^-2]], OutputForm],
    "x ^ (-2)",
    TestID -> "negative-power"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[a + (-b)]], OutputForm],
    "a - b",
    TestID -> "subtraction"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[a - (b + c)]], OutputForm],
    "a - (b + c)",
    TestID -> "subtraction-parentheses"
]

VerificationTest[
    Module[{source},
        source = ToString[JuliaForm[HoldForm[x < y <= z]], OutputForm];
        AllTrue[
            {
                "((__jf_value1, __jf_value2, __jf_value3) -> begin",
                "__jf_value1 < __jf_value2 <= __jf_value3",
                "__jf_require_ordering_pair(__jf_value2, __jf_value3)",
                "Wolfram comparisons involving Indeterminate",
                "end)(x, y, z)"
            },
            StringContainsQ[source, #] &
        ]
    ],
    True,
    TestID -> "mixed-inequality"
]

VerificationTest[
    Quiet[
        {
            ToString[
                JuliaForm[HoldForm[Equal[{True, 1}, {1, 1}]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Less[{1}, {2}]]],
                OutputForm
            ],
            ToString[
                JuliaForm[
                    HoldForm[Inequality[0, Less, {1}, Less, 2]]
                ],
                OutputForm
            ]
        },
        JuliaForm::unsupported
    ],
    {"$Failed", "$Failed", "$Failed"},
    TestID -> "ordinary-comparisons-reject-literal-lists"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[Inequality[]]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "zero-argument-inequality-is-rejected"
]

VerificationTest[
    {
        ToString[JuliaForm[HoldForm[Equal[]]], OutputForm],
        ToString[JuliaForm[HoldForm[Equal[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[Unequal[]]], OutputForm],
        ToString[JuliaForm[HoldForm[Unequal[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[SameQ[]]], OutputForm],
        ToString[JuliaForm[HoldForm[SameQ[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[UnsameQ[]]], OutputForm],
        ToString[JuliaForm[HoldForm[UnsameQ[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[Less[]]], OutputForm],
        ToString[JuliaForm[HoldForm[GreaterEqual[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[Inequality[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[And[]]], OutputForm],
        ToString[JuliaForm[HoldForm[And[x]]], OutputForm],
        ToString[JuliaForm[HoldForm[Or[]]], OutputForm],
        ToString[JuliaForm[HoldForm[Or[x]]], OutputForm]
    },
    {
        "true", "((__jf_value1) -> true)(x)",
        "true", "((__jf_value1) -> true)(x)",
        "true", "((__jf_value1) -> true)(x)",
        "true", "((__jf_value1) -> true)(x)",
        "true", "((__jf_value1) -> true)(x)",
        "((__jf_value1) -> true)(x)",
        "true", "x", "false", "x"
    },
    TestID -> "degenerate-comparison-and-logical-arities"
]

VerificationTest[
    Module[{sources},
        sources = {
            ToString[
                JuliaForm[HoldForm[Equal[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Less[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[LessEqual[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Greater[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[GreaterEqual[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[
                    HoldForm[Inequality[u[], Less, v[], LessEqual, w[]]]
                ],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Unequal[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[SameQ[u[], v[], w[]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[UnsameQ[u[], v[], w[]]]],
                OutputForm
            ]
        };
        AllTrue[
            sources,
            Function[source,
                StringStartsQ[source, "((__jf_value1, "] &&
                    And @@ (StringCount[source, #] == 1 & /@
                        {"u()", "v()", "w()"})
            ]
        ]
    ],
    True,
    TestID -> "pairwise-comparisons-bind-each-operand-once"
]

VerificationTest[
    ToString[JuliaForm[Sin[x] + Exp[y] + Log[z]], OutputForm],
    "exp(y) + log(z) + sin(x)",
    TestID -> "safe-functions"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[E^x + Sqrt[y]]], OutputForm],
    "exp(x) + sqrt(y)",
    TestID -> "exp-and-sqrt"
]

VerificationTest[
    ToString[JuliaForm[ArcTan[x, y]], OutputForm],
    "((__jf_x, __jf_y) -> atan(__jf_y, __jf_x))(x, y)",
    TestID -> "arctan-argument-order"
]

VerificationTest[
    ToString[JuliaForm[Sinc[x]], OutputForm],
    "sinc(x / pi)",
    TestID -> "sinc-normalization"
]

VerificationTest[
    ToString[JuliaForm[Quotient[x, y]], OutputForm],
    "fld(x, y)",
    TestID -> "floor-quotient"
]

VerificationTest[
    {
        ToString[JuliaForm[HoldForm[Min[]]], OutputForm],
        ToString[JuliaForm[HoldForm[Max[]]], OutputForm],
        ToString[JuliaForm[HoldForm[GCD[]]], OutputForm],
        ToString[JuliaForm[HoldForm[Log[b, x]]], OutputForm],
        ToString[JuliaForm[HoldForm[Mod[x, y]]], OutputForm]
    },
    {"Inf", "-Inf", "0", "log(b, x)", "mod(x, y)"},
    TestID -> "mapped-function-supported-arities"
]

VerificationTest[
    Quiet[
        {
            ToString[JuliaForm[HoldForm[Sin[]]], OutputForm],
            ToString[JuliaForm[HoldForm[Sin[x, y]]], OutputForm],
            ToString[JuliaForm[HoldForm[ArcTan[]]], OutputForm],
            ToString[JuliaForm[HoldForm[ArcTan[x, y, z]]], OutputForm],
            ToString[JuliaForm[HoldForm[Log[]]], OutputForm],
            ToString[JuliaForm[HoldForm[Log[a, b, c]]], OutputForm],
            ToString[JuliaForm[HoldForm[Mod[x, y, d]]], OutputForm],
            ToString[JuliaForm[HoldForm[LCM[]]], OutputForm],
            ToString[JuliaForm[HoldForm[Binomial[n]]], OutputForm],
            ToString[JuliaForm[HoldForm[Inverse[m, x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Tr[m, f]]], OutputForm],
            ToString[JuliaForm[HoldForm[Sinc[]]], OutputForm],
            ToString[JuliaForm[HoldForm[Quotient[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Eigenvalues[m]]], OutputForm],
            ToString[JuliaForm[HoldForm[Eigenvalues[m, 2]]], OutputForm]
        },
        JuliaForm::unsupported
    ],
    ConstantArray["$Failed", 15],
    TestID -> "unsafe-function-arities-and-eigenvalues-are-rejected"
]

VerificationTest[
    ToString[JuliaForm[{1, x, "a"}], OutputForm],
    "[1, x, \"a\"]",
    TestID -> "vector"
]

VerificationTest[
    ToString[JuliaForm[{{1, 2}, {3, 4}}], OutputForm],
    "[1 2; 3 4]",
    TestID -> "matrix"
]

VerificationTest[
    ToString[JuliaForm[{{1}, {2}}], OutputForm],
    "[1; 2;;]",
    TestID -> "column-matrix"
]

VerificationTest[
    ToString[JuliaForm[{{1}}], OutputForm],
    "[1;;]",
    TestID -> "one-by-one-matrix"
]

VerificationTest[
    ToString[JuliaForm[{{}, {}}], OutputForm],
    "Matrix{Any}(undef, 2, 0)",
    TestID -> "empty-column-matrix"
]

VerificationTest[
    ToString[JuliaForm[{{1, 2}, {3}}], OutputForm],
    "[[1, 2], [3]]",
    TestID -> "ragged-list"
]

VerificationTest[
    ToString[JuliaForm["a\n\"b\\c$"], OutputForm],
    "\"a\\n\\\"b\\\\c\\$\"",
    TestID -> "string-escaping"
]

VerificationTest[
    ToString[JuliaForm["x" -> {1, 2}], OutputForm],
    "\"x\" => [1, 2]",
    TestID -> "pair"
]

VerificationTest[
    Module[{source},
        source = ToString[
            JuliaForm[<|"x" -> 1, "y" -> {2, 3}|>],
            OutputForm
        ];
        AllTrue[
            {
                "__jf_canonical = Pair[]",
                "Association keys cannot be materialized as a Julia Dict",
                "container-valued Association keys cannot be represented",
                "\"x\" => 1",
                "\"y\" => [2, 3]"
            },
            StringContainsQ[source, #] &
        ]
    ],
    True,
    TestID -> "dict"
]

VerificationTest[
    ToString[JuliaForm[f[x, y]], OutputForm],
    "f(x, y)",
    TestID -> "unknown-user-function"
]

VerificationTest[
    {
        ToString[JuliaForm[foo`x], OutputForm],
        ToString[JuliaForm[Symbol["a$b"]], OutputForm],
        ToString[JuliaForm[Symbol["public"]], OutputForm]
    },
    {"var\"foo`x\"", "var\"a$b\"", "var\"public\""},
    TestID -> "context-and-nonstandard-identifiers"
]

VerificationTest[
    Module[{source},
        source = ToString[JuliaForm[HoldForm[v[[2 ;; -1]]]], OutputForm];
        AllTrue[
            {
                "(:span, 2, -1, 1)",
                "__jf_array_extract",
                "Iterators.product"
            },
            StringContainsQ[source, #] &
        ]
    ],
    True,
    TestID -> "span-index"
]

VerificationTest[
    Module[{source},
        source = ToString[JuliaForm[HoldForm[m[[-1, All]]]], OutputForm];
        AllTrue[
            {"(:index, -1)", "(:all,)", "__jf_array_extract"},
            StringContainsQ[source, #] &
        ]
    ],
    True,
    TestID -> "relative-and-all-index"
]

VerificationTest[
    Module[{source},
        source = ToString[
            JuliaForm[HoldForm[v[[All ;; All]]]],
            OutputForm
        ];
        StringContainsQ[source, "(:span, :first, :last, 1)"]
    ],
    True,
    TestID -> "span-all-uses-first-and-last-endpoints"
]

VerificationTest[
    Module[{source},
        source = ToString[
            JuliaForm[
                HoldForm[Part[<|"x" -> 10, "y" -> 20|>, 2]]
            ],
            OutputForm
        ];
        AllTrue[
            {
                "__jf_token = Ref{Nothing}()",
                "(__jf_token, ",
                "__jf_item[1] === __jf_token",
                "Base.OneTo(length(__jf_pairs))"
            },
            StringContainsQ[source, #] &
        ] && Not[StringContainsQ[source, ":__juliaform_association__"]]
    ],
    True,
    TestID -> "literal-association-part-preserves-rule-order"
]

VerificationTest[
    Module[{source},
        source = ToString[
            JuliaForm[
                HoldForm[
                    Part[{<|"x" -> 1|>, <|"y" -> 2|>}, All, 1]
                ]
            ],
            OutputForm
        ];
        StringCount[source, "__jf_token = Ref{Nothing}()"] == 1 &&
            StringCount[source, "(__jf_token, "] == 2
    ],
    True,
    TestID -> "part-associations-share-one-identity-token"
]

VerificationTest[
    Module[{source},
        source = ToString[JuliaForm[HoldForm[d[[1]]]], OutputForm];
        StringContainsQ[
            source,
            "positional Part on an arbitrary Dict is unsupported"
        ]
    ],
    True,
    TestID -> "runtime-dict-positional-part-is-explicitly-rejected"
]

VerificationTest[
    ToString[HoldForm[(a + b) c], JuliaForm],
    "(a + b) * c",
    TestID -> "tostring-compatibility"
]

VerificationTest[
    Quiet[
        Check[
            ToString[
                x,
                JuliaForm,
                DefinitelyNotAnOption -> 1
            ],
            "rejected"
        ],
        {ToString::fmtval, ToString::optx}
    ],
    "rejected",
    TestID -> "tostring-does-not-swallow-unknown-options"
]

VerificationTest[
    JuliaForm[],
    $Failed,
    {JuliaForm::argx},
    TestID -> "zero-argument-error"
]

VerificationTest[
    JuliaForm[1, 2],
    $Failed,
    {JuliaForm::argx},
    TestID -> "multiple-argument-error"
]

VerificationTest[
    Head[Unevaluated[JuliaForm[x]]],
    JuliaForm,
    TestID -> "wrapper-head"
]

VerificationTest[
    Module[{count = 0, wrapped},
        wrapped = JuliaForm[++count];
        {count, Head[wrapped], First[wrapped]}
    ],
    {1, JuliaForm, 1},
    TestID -> "argument-evaluates-once-and-wrapper-is-preserved"
]

VerificationTest[
    FreeQ[x JuliaForm[x^2], _JuliaForm],
    False,
    TestID -> "assigned-wrapper-affects-later-evaluation"
]

VerificationTest[
    Block[{heldSymbolProbe = -1},
        ToString[
            JuliaForm[HoldForm[a + heldSymbolProbe]],
            OutputForm
        ]
    ],
    "a + heldSymbolProbe",
    TestID -> "holdform-preserves-symbol-with-ownvalue"
]

VerificationTest[
    Module[{sideEffect = 0, result},
        result = Quiet[
            ToString[
                JuliaForm[
                    HoldForm[
                        If[c, sideEffect = 1, sideEffect = 2]
                    ]
                ],
                OutputForm
            ],
            JuliaForm::unsupported
        ];
        {result, sideEffect}
    ],
    {"$Failed", 0},
    TestID -> "held-branches-do-not-evaluate"
]

VerificationTest[
    ToString[FullForm[JuliaForm[x^2]], OutputForm],
    "JuliaForm[Power[x, 2]]",
    TestID -> "fullform-reveals-stored-wrapper"
]

VerificationTest[
    Module[{source},
        source = ToString[
            JuliaForm[HoldForm[SameQ[1, 1.]]],
            OutputForm
        ];
        AllTrue[
            {
                "__jf_same = function",
                "typeof(__jf_left) === typeof(__jf_right)",
                "__jf_left isa AbstractArray",
                "__jf_left isa Pair",
                "__jf_left isa Tuple",
                "SameQ or UnsameQ on a Julia Dict is unsupported"
            },
            StringContainsQ[source, #] &
        ]
    ],
    True,
    TestID -> "sameq-uses-strict-structural-equality"
]

VerificationTest[
    Module[{sources},
        sources = ToString[JuliaForm[#], OutputForm] & /@ {
            HoldForm[SameQ[0., -0.]],
            HoldForm[
                SameQ[Complex[1., 0.], Complex[1., -0.]]
            ]
        };
        AllTrue[
            sources,
            StringContainsQ[#, "iszero"] &
        ]
    ],
    True,
    TestID -> "sameq-normalizes-floating-signed-zero"
]

VerificationTest[
    ToString[JuliaForm[Total[x]], OutputForm],
    "Total(x)",
    TestID -> "type-sensitive-total-is-not-remapped"
]

VerificationTest[
    First[ToBoxes[JuliaForm[1 + x^2], StandardForm]],
    ToBoxes["1 + x ^ 2", StandardForm],
    TestID -> "standard-form-boxes-contain-source"
]

VerificationTest[
    First[First[ToBoxes[JuliaForm[1 + x^2], TraditionalForm]]],
    ToBoxes["1 + x ^ 2", StandardForm],
    TestID -> "traditional-form-boxes-contain-source"
]

VerificationTest[
    ToString[JuliaForm[ComplexInfinity], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-complex-infinity"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[x :> x + 1]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-delayed-rule"
]

VerificationTest[
    ToString[JuliaForm[{{{1, 2}}}], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-rank-three-list"
]

VerificationTest[
    ToString[
        JuliaForm[
            HoldForm[{{1, 2}, {3, 4}} {{5, 6}, {7, 8}}]
        ],
        OutputForm
    ],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-held-list-arithmetic"
]

VerificationTest[
    Quiet[
        {
            ToString[
                JuliaForm[HoldForm[SameQ[{1, 1.}, {1., 1.}]]],
                OutputForm
            ],
            ToString[
                JuliaForm[
                    HoldForm[SameQ["x" -> {1, 1.}, "x" -> {1., 1.}]]
                ],
                OutputForm
            ]
        },
        JuliaForm::unsupported
    ],
    {"$Failed", "$Failed"},
    TestID -> "unsupported-sameq-on-literal-lists"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[Sin[{1, 2}]]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-held-listable-call-on-literal-list"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[Sinc[{1, 2}]]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-special-listable-call-on-literal-list"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[Min[{1, 2}]]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-scalar-call-on-literal-list"
]

VerificationTest[
    ToString[JuliaForm[HoldForm[x += 1]], OutputForm],
    "$Failed",
    {JuliaForm::unsupported},
    TestID -> "unsupported-update-assignment"
]

VerificationTest[
    Quiet[
        {
            ToString[JuliaForm[HoldForm[AppendTo[x, 1]]], OutputForm],
            ToString[JuliaForm[HoldForm[PrependTo[x, 1]]], OutputForm],
            ToString[JuliaForm[HoldForm[AssociateTo[a, k -> v]]], OutputForm],
            ToString[JuliaForm[HoldForm[KeyDropFrom[a, k]]], OutputForm],
            ToString[JuliaForm[HoldForm[ReleaseHold[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[OptionsPattern[]]], OutputForm],
            ToString[JuliaForm[HoldForm[PatternSequence[x, y]]], OutputForm],
            ToString[JuliaForm[HoldForm[Except[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Longest[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Shortest[x]]], OutputForm],
            ToString[
                JuliaForm[HoldForm[OrderlessPatternSequence[x, y]]],
                OutputForm
            ],
            ToString[JuliaForm[HoldForm[KeyValuePattern[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Slot[1]]], OutputForm],
            ToString[JuliaForm[HoldForm[SlotSequence[1]]], OutputForm],
            ToString[JuliaForm[HoldForm[SetOptions[f, a -> b]]], OutputForm],
            ToString[JuliaForm[HoldForm[SetAttributes[x, Listable]]], OutputForm],
            ToString[JuliaForm[HoldForm[ClearAttributes[x, Listable]]], OutputForm],
            ToString[JuliaForm[HoldForm[Protect[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Unprotect[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Clear[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[ClearAll[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Remove[x]]], OutputForm],
            ToString[JuliaForm[HoldForm[Not[]]], OutputForm],
            ToString[JuliaForm[HoldForm[Part[]]], OutputForm]
        },
        JuliaForm::unsupported
    ],
    ConstantArray["$Failed", 24],
    TestID -> "unsupported-state-pattern-and-held-fallback-boundary"
]

VerificationTest[
    Quiet[
        {
            ToString[
                JuliaForm[HoldForm[Part[v, Span[1, 3, 0]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Part[v, UpTo[2]]]],
                OutputForm
            ],
            ToString[
                JuliaForm[HoldForm[Part[v, Span[1, UpTo[2]]]]],
                OutputForm
            ]
        },
        JuliaForm::unsupported
    ],
    ConstantArray["$Failed", 3],
    TestID -> "unsupported-part-selectors-are-rejected"
]
