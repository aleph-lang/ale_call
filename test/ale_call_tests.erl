-module(ale_call_tests).
-include_lib("eunit/include/eunit.hrl").

generate_test() ->
    SimpleAST = #{
        <<"type">> => <<"Add">>,
        <<"numberExpr1">> => #{<<"type">> => <<"Int">>, <<"value">> => <<"5">>},
        <<"numberExpr2">> => #{<<"type">> => <<"Int">>, <<"value">> => <<"6">>}
    },
    Result = ale_call:generate(SimpleAST),
    ?assertMatch({ok, _BinaryResult}, Result).

generate_from_file_test() ->
    FakeFile = "test/data/fake.json",
    Result = ale_call:generate_from_file(FakeFile),
    ?assertMatch({error, _}, Result).

path_config_test() ->
    DefaultPath = ale_call:get_rust_generator_path(),
    ?assert(is_list(DefaultPath)),
    ok = ale_call:set_rust_generator_path("/tmp/fake_path"),
    NewPath = ale_call:get_rust_generator_path(),
    ?assertEqual("/tmp/fake_path", NewPath).

check_rust_generator_test() ->
    Result = ale_call:check_rust_generator(),
    case Result of
        {ok, Path} -> ?assert(is_list(Path));
        {error, not_found} -> ok
    end.

diagnostic_info_test() ->
    ok = ale_call:diagnostic_info(),
    ok.

