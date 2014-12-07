-module(amqp_arpc_server_pool_sup).

-behaviour(supervisor).

%% API
-export([start_link/3]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(WorkerModule,PoolName,PoolSize) ->
    supervisor:start_link(?MODULE, [WorkerModule,PoolName,PoolSize]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([WorkerModule,PoolName,PoolSize]) ->
    WorkerArgs=[],
    PoolArgs = [
	{name, {local,PoolName}},
	{worker_module, WorkerModule},
	{size, PoolSize},
	{max_overflow,2*PoolSize}
	],
    PoolSpecs=[
	poolboy:child_spec(PoolName, PoolArgs, WorkerArgs)
    ],
    {ok, {{one_for_one, 10, 10}, PoolSpecs}}.
