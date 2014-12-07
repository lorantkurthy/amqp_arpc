-module(amqp_arpc_conn).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/2]).
-export([get_conn/2]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state,{
    connection
}).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

get_conn(Name,ConnArgs) ->
    case get_pid(Name) of
	{ok,Pid} -> {ok,Pid};
	_ -> 
	    amqp_arpc_conn_sup:start_conn(Name,ConnArgs),
	    get_pid(Name)
    end.

get_pid(Name) ->
    case whereis(Name) of
	Pid when is_pid(Pid) ->
	    case is_process_alive(Pid) of
		true ->
		    gen_server:call(Name,get_conn);
		_ ->
		    {error,process_not_alive}
    	    end;
	_ ->
	    {error,no_pid}
    end.

start_link(Name,ConnArgs) ->
    gen_server:start_link({local, Name}, ?MODULE, [ConnArgs], []).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([ConnArgs]) ->
    process_flag(trap_exit, true),
    {ok, Connection} = amqp_connection:start(ConnArgs),
    erlang:monitor(process,Connection),
    {ok,#state{connection=Connection}}.

handle_call(get_conn, _From, #state{connection=Connection}=State) ->
    {reply, {ok,Connection}, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', _Ref, process, Pid2, _Reason}, #state{connection=Conn}=State) when Pid2==Conn ->
    {stop, normal, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{connection=Connection}=_State) ->
    catch amqp_connection:close(Connection),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

