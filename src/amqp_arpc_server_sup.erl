-module(amqp_arpc_server_sup).

-behaviour(supervisor).

%% API
-export([start_link/0,start_child/5]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, transient, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    ChildSpec=?CHILD(amqp_arpc_server,worker),
    {ok, { {simple_one_for_one, 5, 10}, [ChildSpec]} }.

start_child(Connection, Exchange, WorkerModule, PoolName, PoolSize) ->
    supervisor:start_child(?MODULE, [Connection, Exchange, WorkerModule, PoolName, PoolSize]).
