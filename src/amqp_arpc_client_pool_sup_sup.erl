-module(amqp_arpc_client_pool_sup_sup).

-behaviour(supervisor).

%% API
-export([start_link/0,start_child/4,terminate_child/1]).

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
    ChildSpec=?CHILD(amqp_arpc_client_pool_sup,worker),
    {ok, { {simple_one_for_one, 10, 10}, [ChildSpec]} }.

start_child(Connection, Exchange, PoolName, PoolSize) ->
    supervisor:start_child(?MODULE, [Connection, Exchange, PoolName, PoolSize]).

terminate_child(Pid) ->
    supervisor:terminate_child(?MODULE, Pid).
