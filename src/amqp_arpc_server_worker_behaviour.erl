-module(amqp_arpc_server_worker_behaviour).

-callback request(WorkerPid :: pid() , Payload :: binary(), ReplyFun :: fun((binary()) -> any() )) -> 'ok'.
