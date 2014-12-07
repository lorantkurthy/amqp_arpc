amqp_arpc
=========

Erlang asynchronous RPC client and server for RabbitMQ based on poolboy pools

Usage:

Prerequisites:

    1. working RabbitMQ node on host example.com with name rabbitmq_node,
    2. a virtual host inside this node with name "virtual_host"
    3. a RabbitMQ user inside this node with name "username" and with password "password"
    4. an exchange named "arpc_exchange" inside this node which is accessible for "username" user

Common code:

    -define(EXCHANGE,<<"arpc_exchange">>).

    -define(CONNECTION,#amqp_params_direct{
	username= << "username" >>,
	password= << "password" >>,
	virtual_host= << "virtual_host" >>,
	node='rabbitmq_node@example.com'
    }).

Start server:

    start_server() ->
	{ok,Conn} = amqp_arpc_conn:get_conn(amqp_conn_server,?CONNECTION),
	%amqp_arpc_server_test_pool is the name of the poolboy pool, change it to any unique atom
	{ok,SrvPid} = amqp_arpc_server:start(Conn,?EXCHANGE,?WORKER_MODULE,amqp_arpc_server_test_pool),
	SrvPid.

Start client and make a call:

    start_client() ->
	{ok,Conn} = amqp_arpc_conn:get_conn(amqp_conn_client,?CONNECTION),
	%amqp_arpc_client_test_pool is the name of the poolboy pool, change it to any unique atom
	{ok,ClientPid} = amqp_arpc_client:start(Conn,?EXCHANGE,amqp_arpc_client_test_pool),
        Rep = amqp_arpc_client:call(amqp_arpc_client_test_pool,[test,"test",100]),
	Rep.
