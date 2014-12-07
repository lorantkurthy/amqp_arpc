-module(amqp_arpc_client_pool_sup).

-behaviour(supervisor).

%% API
-export([start_link/4]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(Connection,Exchange,PoolName,PoolSize) ->
    supervisor:start_link(?MODULE, [Connection,Exchange,PoolName,PoolSize]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([Connection,Exchange,PoolName,PoolSize]) ->
    PoolArgs = [
	{name, {local,PoolName}},
	{worker_module, amqp_arpc_client_pool_worker},
	{size, PoolSize},
	{max_overflow,2*PoolSize}
	],
    WorkerArgs=[Connection,Exchange],
    PoolSpecs=[
	poolboy:child_spec(PoolName, PoolArgs, WorkerArgs)
    ],
    {ok, {{one_for_one, 10, 10}, PoolSpecs}}.
