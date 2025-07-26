%%%-------------------------------------------------------------------
%%% @doc
%%% ale_call - Erlang interface to the Aleph Rust compiler binary
%%%
%%% This module provides functions to convert Aleph ASTs (in Erlang terms)
%%% into JSON and call the Rust Aleph compiler to generate code.
%%% It supports configuring the Rust binary path and specifying output type.
%%%-------------------------------------------------------------------
-module(ale_call).
-include_lib("kernel/include/file.hrl").

%% Public API exports
-export([
    generate/1,
    generate/2,
    generate_from_file/1,
    generate_from_file/2,
    set_rust_generator_path/1,
    get_rust_generator_path/0,
    check_rust_generator/0,
    diagnostic_info/0,
    call_rust_generator_direct/1,
    call_rust_generator_direct/2,
    call_rust_generator_port/1,
    call_rust_generator_port/2
]).

%% Default path to the Rust Aleph compiler executable
-define(DEFAULT_RUST_GENERATOR, "../aleph/target/release/alephc.exe").

-record(generator_config, {
    rust_path = ?DEFAULT_RUST_GENERATOR
}).

-define(CONFIG_KEY, ale_call_config).

%%%===================================================================
%%% @doc Convert an Aleph AST Erlang term into formatted JSON binary.
%%% @spec to_json(term()) -> binary()
%%%===================================================================
to_json(AlephTree) ->
    jsx:encode(AlephTree, [{space, 2}, {indent, 2}]).

%%%===================================================================
%%% Public API
%%%===================================================================

%%%===================================================================
%%% @doc Generate code from an Aleph AST.
%%% Uses "ale" as the default output type.
%%% @spec generate(term()) -> {ok,binary()} | {error,term()}
%%%===================================================================
generate(AlephAST) ->
    generate(AlephAST, "ale").

%%%===================================================================
%%% @doc Generate code from an Aleph AST with specified output type.
%%% @spec generate(term(), string()) -> {ok,binary()} | {error,term()}
%%%===================================================================
generate(AlephAST, OutputType) ->
    JsonAST = to_json(AlephAST),
    call_rust_generator_direct(JsonAST, OutputType).

%%%===================================================================
%%% @doc Generate code from a JSON file.
%%% Uses "ale" as the default output type.
%%% @spec generate_from_file(string()) -> {ok,binary()} | {error,term()}
%%%===================================================================
generate_from_file(JsonFile) ->
    generate_from_file(JsonFile, "ale").

%%%===================================================================
%%% @doc Generate code from a JSON file with specified output type.
%%% Reads JSON content then passes to Rust compiler.
%%% @spec generate_from_file(string(), string()) -> {ok,binary()} | {error,term()}
%%%===================================================================
generate_from_file(JsonFile, OutputType) ->
    case file:read_file(JsonFile) of
        {ok, JsonContent} -> call_rust_generator_direct(binary_to_list(JsonContent), OutputType);
        Error -> Error
    end.

%%%===================================================================
%%% @doc Set the file path of the Rust Aleph compiler executable.
%%% Stored in the process dictionary for current process.
%%% @spec set_rust_generator_path(string()) -> ok
%%%===================================================================
set_rust_generator_path(Path) ->
    put(?CONFIG_KEY, #generator_config{rust_path = Path}),
    ok.

%%%===================================================================
%%% @doc Get the Rust Aleph compiler executable path.
%%% Checks process dictionary, then environment variable ALEPHC_BIN,
%%% else returns the default path.
%%% @spec get_rust_generator_path() -> string()
%%%===================================================================
get_rust_generator_path() ->
    case get(?CONFIG_KEY) of
        undefined ->
            case os:getenv("ALEPHC_BIN") of
                false -> ?DEFAULT_RUST_GENERATOR;
                EnvPath -> EnvPath
            end;
        Config -> Config#generator_config.rust_path
    end.

%%%===================================================================
%%% @doc Check if the Rust Aleph compiler executable exists and is a file.
%%% Returns {ok, Path} or {error, not_found}.
%%% @spec check_rust_generator() -> {ok,string()} | {error,not_found}
%%%===================================================================
check_rust_generator() ->
    RustPath = get_rust_generator_path(),
    case filelib:is_regular(RustPath) of
        true -> {ok, RustPath};
        false -> {error, not_found}
    end.

%%%===================================================================
%%% @doc Print diagnostic information about the Rust compiler configuration.
%%% @spec diagnostic_info() -> ok
%%%===================================================================
diagnostic_info() ->
    RustPath = get_rust_generator_path(),
    io:format("=== ALEPH GEN Diagnostic ===~n"),
    io:format("Rust compiler path: ~s~nFile exists: ~p~n", [RustPath, filelib:is_regular(RustPath)]),
    ok.

%%%===================================================================
%%% Internal functions to invoke Rust Aleph compiler
%%%===================================================================

%%%===================================================================
%%% @doc Call Rust compiler using OS command,
%%% piping the JSON AST via echo and reading output.
%%% Defaults to output type "ale".
%%% @spec call_rust_generator_direct(binary() | string()) -> {ok,binary()} | {error,term()}
%%% @spec call_rust_generator_direct(binary() | string(), string()) -> {ok,binary()} | {error,term()}
%%%===================================================================
call_rust_generator_direct(JsonAST) ->
    call_rust_generator_direct(JsonAST, "ale").

call_rust_generator_direct(JsonAST, OutputType) ->
    RustPath = get_rust_generator_path(),
    JsonData = case is_binary(JsonAST) of
        true -> JsonAST;
        false -> list_to_binary(JsonAST)
    end,
    %% Compact JSON by removing all whitespace
    CompactJson = re:replace(JsonData, "\\s+", "", [global, {return, binary}]),
    %% Prepare OS-specific command for piping JSON into Rust compiler
    Command = case os:type() of
        {win32, _} ->
            "echo " ++ binary_to_list(CompactJson) ++ " | \"" ++ RustPath ++ "\" -i ast_json -o " ++ OutputType;
        _ ->
            "echo '" ++ binary_to_list(CompactJson) ++ "' | " ++ RustPath ++ " -i ast_json -o " ++ OutputType
    end,
    try
        Result = os:cmd(Command),
        {ok, list_to_binary(Result)}
    catch
        _:_ -> {error, command_failed}
    end.

%%%===================================================================
%%% @doc Call Rust compiler using Erlang port for better IO control.
%%% Sends compact single-line JSON, receives output from stdout.
%%% Defaults to output type "ale".
%%% @spec call_rust_generator_port(binary() | string()) -> {ok,binary()} | {error,term()}
%%% @spec call_rust_generator_port(binary() | string(), string()) -> {ok,binary()} | {error,term()}
%%%===================================================================
call_rust_generator_port(JsonAST) ->
    call_rust_generator_port(JsonAST, "ale").

call_rust_generator_port(JsonAST, OutputType) ->
    RustPath = get_rust_generator_path(),
    JsonData = case is_binary(JsonAST) of
        true -> JsonAST;
        false -> list_to_binary(JsonAST)
    end,
    %% Compact JSON into single line to avoid port issues
    CompactJson = re:replace(JsonData, "\\s+", " ", [global, {return, binary}]),
    Command = RustPath ++ " -i ast_json -o " ++ OutputType,
    Port = open_port({spawn, Command}, [stream, use_stdio, exit_status, binary, eof]),

    port_command(Port, CompactJson),
    receive_port_output(Port, <<>>).

%%%===================================================================
%%% @private
%%% Receive data from port until process exit or timeout
%%% Accumulates all output in binary.
%%%===================================================================
receive_port_output(Port, Acc) ->
    receive
        {Port, {data, Data}} ->
            receive_port_output(Port, <<Acc/binary, Data/binary>>);
        {Port, {exit_status, 0}} ->
            port_close(Port),
            {ok, Acc};
        {Port, {exit_status, Status}} ->
            port_close(Port),
            {error, {exit_status, Status, Acc}};
        {Port, eof} ->
            receive_port_output(Port, Acc)
    after 10000 ->
        port_close(Port),
        {error, timeout}
    end.

