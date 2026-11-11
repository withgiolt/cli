-module(giolt_ffi_process).
-export([available/2, exit/1, run_attached/2]).

% nouse_stdio moves the port's own pipes to file descriptors 3 and 4, so the
% child inherits the terminal: colours, prompts and Ctrl-C reach it directly.
run_attached(Command, Args) ->
    case os:find_executable(unicode:characters_to_list(Command)) of
        false ->
            {error, <<"Could not find `", Command/binary, "` on the PATH.">>};
        Path ->
            Port = open_port({spawn_executable, Path},
                             [exit_status, nouse_stdio, hide, {args, Args}]),
            receive
                {Port, {exit_status, Status}} -> {ok, Status}
            end
    end.

available(Command, Args) ->
    case os:find_executable(unicode:characters_to_list(Command)) of
        false ->
            false;
        Path ->
            Port = open_port({spawn_executable, Path},
                             [exit_status, stderr_to_stdout, hide, {args, Args}]),
            wait_for_success(Port)
    end.

wait_for_success(Port) ->
    receive
        {Port, {data, _}} -> wait_for_success(Port);
        {Port, {exit_status, Status}} -> Status =:= 0
    end.

exit(Code) ->
    erlang:halt(Code).
