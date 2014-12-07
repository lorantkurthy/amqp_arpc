-module(amqp_arpc_server_worker_behaviour).

-callback request(WorkerPid :: pid() , Payload :: binary(), ReplyFun :: fun((binary()) -> any() )) -> 'ok'.

-callback start_link(WorkerArgs) -> {ok, Pid} |
                                    {error, {already_started, Pid}} |
                                    {error, Reason} when
    WorkerArgs :: proplists:proplist(),
    Pid        :: pid(),
    Reason     :: term().
