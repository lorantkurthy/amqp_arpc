-module(amqp_arpc_server).
-behaviour(gen_server).

-include("amqp_arpc.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start/4,start/5,stop/1,start_link/5]).

-record(state,{
    conn,
    channel,
    pool,
    pool_name,
    worker_module
}).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start(Connection, Exchange, WorkerModule, PoolName) ->
    start(Connection, Exchange, WorkerModule, PoolName, ?DEFAULT_POOL_SIZE).

start(Connection, Exchange, WorkerModule, PoolName, PoolSize) ->
    amqp_arpc_server_sup:start_child(Connection, Exchange, WorkerModule, PoolName, PoolSize).

stop(Pid) ->
    gen_server:call(Pid, stop).

start_link(Connection, Exchange, WorkerModule, PoolName, PoolSize) ->
    gen_server:start_link(?MODULE,[Connection, Exchange, WorkerModule, PoolName, PoolSize],[]).
    
%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Connection, Exchange, WorkerModule, PoolName, PoolSize]) ->
    process_flag(trap_exit,true),
    erlang:monitor(process, Connection),

    {ok, Channel} = amqp_connection:open_channel(
                        Connection, {amqp_direct_consumer, [self()]}),
    erlang:monitor(process,Channel),

    {ok,PoolPid}=amqp_arpc_server_pool_sup_sup:start_child(WorkerModule, PoolName, PoolSize),
    erlang:monitor(process, PoolPid),

    #'queue.declare_ok'{queue = Queue} =
        amqp_channel:call(Channel, #'queue.declare'{auto_delete=true, durable=false}),
    #'queue.bind_ok'{} =
        amqp_channel:call(Channel, #'queue.bind'{queue=Queue,exchange=Exchange}),
    #'basic.consume_ok'{} = 
	amqp_channel:call(Channel, #'basic.consume'{queue = Queue, no_ack = true}),

    {ok, #state{conn=Connection,pool=PoolPid,pool_name=PoolName,channel=Channel,worker_module=WorkerModule}}.

handle_call(stop, _From, State) ->
    {stop, normal, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({response,WorkerPid,CorrelationId,ReplyTo,Response}, #state{channel=Channel,pool_name=PoolName} = State) ->

    poolboy:checkin(PoolName, WorkerPid),

    Properties = #'P_basic'{correlation_id = CorrelationId},
    Publish = #'basic.publish'{routing_key = ReplyTo},
    amqp_channel:call(Channel, Publish, #amqp_msg{props = Properties,
                                                  payload = Response}),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% @private
handle_info(shutdown, State) ->
    {stop, normal, State};

%% @private
handle_info(#'basic.cancel_ok'{}, State) ->
    {stop, normal, State};

%% @private
handle_info({#'basic.deliver'{},
             #amqp_msg{props = Props, payload = Payload}},
             #state{pool_name=PoolName,worker_module=WorkerModule} = State) ->

    #'P_basic'{correlation_id = CorrelationId,
               reply_to = ReplyTo} = Props,

    SelfPid=self(),
    WorkerPid = poolboy:checkout(PoolName),
    ResponseFun=fun(Response) ->
	gen_server:cast(SelfPid,{response,WorkerPid,CorrelationId,ReplyTo,Response})
    end,
    WorkerModule:request(WorkerPid, Payload, ResponseFun),

    {noreply, State};

handle_info({'DOWN', _Ref, process, Pid2, _Reason}, #state{conn=ConnPid,pool=PoolPid,channel=Channel}=State)
    when Pid2==ConnPid orelse Pid2==PoolPid orelse Pid2==Channel ->
    {stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{pool=PoolPid,channel=Channel}=_State) ->
    catch amqp_arpc_server_pool_sup_sup:stop_child(PoolPid),
    catch amqp_channel:close(Channel),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

