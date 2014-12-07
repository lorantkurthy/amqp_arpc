-module(amqp_arpc_client).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-include("amqp_arpc.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start/3,start/4,stop/1,start_link/4]).
-export([call/2]).

-record(state,{
    conn,
    pool
}).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start(Connection, Exchange, PoolName) ->
    start(Connection, Exchange, PoolName, ?DEFAULT_POOL_SIZE).

start(Connection, Exchange, PoolName, PoolSize) ->
    amqp_arpc_client_sup:start_child(Connection, Exchange, PoolName, PoolSize).

stop(Pid) ->
    gen_server:call(Pid, stop).

start_link(Connection, Exchange, PoolName, PoolSize) ->
    gen_server:start_link(?MODULE,[Connection, Exchange, PoolName, PoolSize],[]).
    
call(PoolName,Rpc) ->
    poolboy:transaction(PoolName, fun(Worker) ->
	gen_server:call(Worker, {rpc,Rpc})
    end).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Connection, Exchange, PoolName, PoolSize]) ->
    process_flag(trap_exit,true),
    {ok,PoolPid}=amqp_arpc_client_pool_sup_sup:start_child(Connection, Exchange, PoolName, PoolSize),
    monitor(process, Connection),
    monitor(process, PoolPid),
    {ok, #state{conn=Connection,pool=PoolPid}}.

handle_call(stop, _From, State) ->
    {stop, normal, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', _Ref, process, Pid2, _Reason}, #state{conn=ConnPid,pool=PoolPid}=State) when Pid2==ConnPid orelse Pid2==PoolPid->
    {stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{pool=PoolPid}=_State) ->
    catch amqp_arpc_client_pool_sup_sup:terminate_child(PoolPid),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

