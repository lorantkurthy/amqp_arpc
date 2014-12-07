-module(amqp_arpc_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    ChildSpecs=[
	?CHILD(amqp_arpc_conn_sup,supervisor),
	?CHILD(amqp_arpc_server_sup,supervisor),
	?CHILD(amqp_arpc_server_pool_sup_sup,supervisor),
	?CHILD(amqp_arpc_client_sup,supervisor),
	?CHILD(amqp_arpc_client_pool_sup_sup,supervisor)
    ],	
    {ok, { {one_for_one, 10, 10}, ChildSpecs} }.

