amqp_arpc
=========

Erlang asynchronous RPC client and server for RabbitMQ based on poolboy pools

Usage:

Prerequisites:

    1. working RabbitMQ node on host example.com with name rabbitmq_node,
    2. a virtual host inside this node with name "virtual_host"
    3. a RabbitMQ user inside this node with name "username" and with password "password"
    4. an exchange named "arpc_exchange" inside this node which is accessible for "username" user

Common code:

    -define(EXCHANGE,<<"arpc_exchange">>).

    -define(CONNECTION,#amqp_params_direct{
	username= << "username" >>,
	password= << "password" >>,
	virtual_host= << "virtual_host" >>,
	node='rabbitmq_node@example.com'
    }).

Start server:

    -define(WORKER_MODULE,test_worker).
    
    start_server() ->
	{ok,Conn} = amqp_arpc_conn:get_conn(amqp_conn_server,?CONNECTION),
	%amqp_arpc_server_test_pool is the name of the poolboy pool, change it to any unique atom
	{ok,SrvPid} = amqp_arpc_server:start(Conn,?EXCHANGE,?WORKER_MODULE,amqp_arpc_server_test_pool),
	SrvPid.

Start client and make a call:

    start_client() ->
	{ok,Conn} = amqp_arpc_conn:get_conn(amqp_conn_client,?CONNECTION),
	%amqp_arpc_client_test_pool is the name of the poolboy pool, change it to any unique atom
	{ok,ClientPid} = amqp_arpc_client:start(Conn,?EXCHANGE,amqp_arpc_client_test_pool),
        Rep = amqp_arpc_client:call(amqp_arpc_client_test_pool,[test,"test",100]),
	Rep.

test_worker module:

    -module(test_worker).
    -behaviour(gen_server).
    -behaviour(amqp_arpc_server_worker_behaviour).

    -export([start_link/1,request/3]).

    -export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

    -record(state,{
    }).

    start_link([]) ->
	gen_server:start_link(?MODULE, [], []).

    request(WorkerPid,Payload,ReplyFun) ->
	gen_server:cast(WorkerPid,{rpc,Payload,ReplyFun}).

    init(_Args) ->
	process_flag(trap_exit, true),
        io:format("srv pool worker init ~p~n",[self()]),
	{ok, #state{}}.

    handle_call(_Request, _From, State) ->
	{reply, ok, State}.

    handle_cast({rpc,Payload,ReplyFun}, State) when is_binary(Payload) ->
        ReplyFun(term_to_binary(handle_request(binary_to_term(Payload)))),
	{noreply, State};

    handle_cast(_Msg, State) ->
	{noreply, State}.

    handle_info(_Info, State) ->
	{noreply, State}.

    terminate(_Reason, _State) ->
        io:format("srv pool worker terminate ~p~n",[self()]),
	ok.

    code_change(_OldVsn, State, _Extra) ->
        {ok, State}.

    handle_request(Payload) ->
	{hello,Payload}.
