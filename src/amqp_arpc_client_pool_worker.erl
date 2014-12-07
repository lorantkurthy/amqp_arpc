-module(amqp_arpc_client_pool_worker).
-behaviour(gen_server).
-define(SERVER, ?MODULE).

-include("amqp_arpc.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/1]).

%% ------------------------------------------------------------------
%% gen_server Function Exports
%% ------------------------------------------------------------------

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {channel,
                exchange,
                correlations = dict:new(),
                correlation_id = 0}).

-define(REPLY_QUEUE,<<"amq.rabbitmq.reply-to">>).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link([Connection,Exchange]) ->
    gen_server:start_link(?MODULE, [Connection,Exchange], []).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Connection,Exchange]) ->
    process_flag(trap_exit, true),
    {ok, Channel} = amqp_connection:open_channel(Connection, {amqp_direct_consumer, [self()]}),
    erlang:monitor(process,Channel),
    #'basic.consume_ok'{} = amqp_channel:call(Channel, #'basic.consume'{queue = ?REPLY_QUEUE, no_ack = true}),
    {ok, #state{exchange=Exchange,channel=Channel}}.

handle_call({rpc,Rpc}, From, #state{}=State) ->
    NewState = publish(term_to_binary(Rpc), From, State),
    {noreply,NewState};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({'DOWN', _MRef, process, Pid2, _Info}, #state{channel=Channel}=State) when Pid2==Channel ->
    {stop,normal, State};

handle_info(#'basic.cancel_ok'{}, State) ->
    {stop, normal, State};

handle_info({#'basic.deliver'{},
             #amqp_msg{props = #'P_basic'{correlation_id = Id},
                       payload = Payload}},
            State = #state{correlations = Correlations}) ->
    From = dict:fetch(Id, Correlations),
    gen_server:reply(From, binary_to_term(Payload)),
    {noreply, State#state{correlations = dict:erase(Id, Correlations) }};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{channel = Channel}) ->
    catch amqp_channel:close(Channel),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

publish(Payload, From,
        State = #state{channel = Channel,
                       exchange = Exchange,
                       correlation_id = CorrelationId,
                       correlations = Correlations}) ->

    EncodedCorrelationId = base64:encode(<<CorrelationId:64>>),
    Props = #'P_basic'{correlation_id = EncodedCorrelationId, content_type = <<"application/octet-stream">>, reply_to = ?REPLY_QUEUE},
    Publish = #'basic.publish'{exchange = Exchange, mandatory = true},
    amqp_channel:call(Channel, Publish, #amqp_msg{props = Props, payload = Payload}),
    State#state{correlation_id = CorrelationId + 1, correlations = dict:store(EncodedCorrelationId, From, Correlations)}.
