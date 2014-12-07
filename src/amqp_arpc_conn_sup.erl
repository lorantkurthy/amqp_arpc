-module(amqp_arpc_conn_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1,start_conn/2]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, temporary, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init(_Args) ->
    ChildSpec=?CHILD(amqp_arpc_conn,worker),
    {ok, { {simple_one_for_one, 5, 10}, [ChildSpec]} }.

start_conn(Name,ConnArgs) ->
    supervisor:start_child(amqp_arpc_conn_sup,[Name,ConnArgs]).
