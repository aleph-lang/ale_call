# ale_call

`ale_call` is an Erlang interface module to the [Aleph](https://github.com/aleph-lang/aleph) Rust compiler. It facilitates code generation from Aleph ASTs by converting Erlang terms to JSON and invoking the Aleph Rust binary.

## Features

- Convert Aleph Abstract Syntax Trees (AST) into JSON format.
- Call Aleph Rust compiler executable directly or via Erlang ports.
- Configure the path to the Aleph Rust binary via API or environment variable.
- Specify output code type (default is `ale`) for flexible generation targets.
- Simple error handling with `{ok, Result}` / `{error, Reason}` tuples.
- Designed for easy integration in Erlang/OTP projects and Hex.pm packaging.

 ## Example

 ```
 1> AST = #{
         <<"type">> => <<"Add">>,
         <<"numberExpr1">> => #{
             <<"type">> => <<"Int">>,
             <<"value">> => <<"3">>
         },
         <<"numberExpr2">> => #{
             <<"type">> => <<"Int">>,
             <<"value">> => <<"4">>
         }
     }.
  #{<<"numberExpr1">> =>
        #{<<"type">> => <<"Int">>,<<"value">> => <<"3">>},
    <<"numberExpr2">> =>
        #{<<"type">> => <<"Int">>,<<"value">> => <<"4">>},
    <<"type">> => <<"Add">>}
  2> {ok, Code} = ale_call:generate(AST).
  {ok,<<"3 + 4\n">>}
```

