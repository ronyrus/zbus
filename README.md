# About

zbus is a message bus in Lua. 

It allows processes to provide or call methods between each other and to publish and subscribe to notifications. The functionality provided should cover many use cases where [dbus](http://www.freedesktop.org/wiki/Software/dbus) may be suitable.

In opposite to dbus, zbus neither describes a message format nor requires XML for service registration etc. It is possible to register methods which handle multiple method-urls to keep the broker slim. Anyhow, zbus comes with an optional JSON serializer, which allows convenient and typed interfaces.

## Files

-    **zbusd.lua**: A Lua program, which acts as "message broker" or "router"
-    **zbus.lua**: The Lua module, which provides an API for being a zbus member (zbus.member)
-    **zbus/json.lua**: An optional Lua module, which defines JSON serialization methods

## Purpose

zbus is designed to allow:

-    inter-process method calls
-    inter-process notifications (publish/subscribe)

To achieve this, you have to become a zbus.member. zbus members can:

-  register callbacks to handle inter-process method calls.
-  register callbacks to handle notifications (publish/**subscribe**)
-  send notificiations (**publish**/subscribe)
-  call methods in another process
-  a extendable event loop

## Requirements

zbusd heavily relies on [lua-zmq](https://github.com/Neopallium/lua-zmq) and [lua-ev](https://github.com/brimworks/lua-ev). The optional JSON message wrapper (zbus/json.lua) requires [lua-cjson](http://www.kyne.com.au/~mark/software/lua-cjson.php). They are all available via luarocks and will be installed automatically with the zbus rock.

## Other Languages like C,Python,...

Even if the broker (zbusd.lua) and the modules provided are written in Lua, zbus members could be written in **any language** with support for zeromq (and multi-part messages), as [lua-zmq](https://github.com/Neopallium/lua-zmq) does.

## Protocol

zbus defines a simple protocol based on zeromq **multi-part messages**.This allows zbusd.lua to effectively recognize (or simply forward):

-    method-urls
-    method-arguments
-    return-values
-    exceptions
-    notification-data

The zbus protocol itself is aware of any dataformat but provides a default implementation for JSON which allows a very convient zbus.

## Build

zbus is Lua-only, so no build/compile process is involved.

## Install

Latest version from github:

       $ sudo luarocks install https://github.com/lipp/zbus/raw/master/rockspecs/zbus-scm-1.rockspec


or from cloned repo directory:

   $ sudo luarocks make rockspecs/zbus-scm-1.rockspec

There is no official release yet.

# Example

## zbusd.lua

**All examples require zbusd to run**:

      $ zbusd.lua


It is a daemon process and will never return. If the zbusd.lua daemon is not started, all zbus.members will block until zbusd.lua is started.

## Providing an echo service and client without argument serialization

### The server providing the 'echo' method

```lua
-- load zbus module
local zbus = require'zbus'

-- create a default zbus member
local member = zbus.member()

-- register a function, which will be called, when a zbus-message's url matches expression
member:replier_add(
	  -- the expression to match ^matches string begin, $ matches string end	
          '^echo$', 
	  -- the callback gets passed in the matched url, in this case always 'echo', 
	  -- and the unserialized argument string	
	  function(url,argument_str) 
	       print(url,argument_str)
	       return argument_str
         end)

-- start the event loop, which will forward all 'echo' calls to member.
member:loop()

```

### The client calling the 'echo' method

```lua
-- load zbus module
local zbus = require'zbus'

-- create a default zbus member
local member = zbus.member()

-- call the service function and pass some argument string
local result_str = member:call(
	'echo', -- the method url/name
	'Hello there' -- the argument string
)
-- verify that the echo service works
assert(result_str=='Hello there')
```

### Run the example
check is zbusd.lua is running! The echo_server.lua will never return (it is a service!) and must be terminated with aisgnal of choice, e.g. kill.

      $ lua examples/echo_server.lua &
      $ lua examples/echo_client


## Providing an echo service and client with JSON serialization

If a serialization config is provided, we can work with multiple typed arguments and return values.
What the zbus_json_config does, is wrapping/unwrapping the arguments and results to a JSON array.

### The server providing the 'echo' method

```lua
-- load zbus module
local zbus = require'zbus'

-- load the JSON message format serilization
local zbus_json_config = require'zbus.json'

-- create a zbus member with the specified serializers
local member = zbus.member(zbus_json_config)

-- register a function, which will be called, when a zbus-message's url matches expression
member:replier_add(
	 -- the expression to match	
          '^echo$', 
	  -- the callback gets passed in the matched url, in this case always 'echo', 
	  -- and the unserialized argument string	
          function(url,...) 
		print(url,...)
		return ...
          end)

-- start the event loop, which will forward all 'echo' calls to member.
member:loop()

```

### The client calling the 'echo' method

```lua
-- load zbus module
local zbus = require'zbus'

-- load the JSON message format serilization
local zbus_json_config = require'zbus.json'

-- create a zbus member with the specified serializers
local member = zbus.member(zbus_json_config)

-- call the service function and pass some arguments
local res = {member:call(
	'echo', -- the method url/name
	'Hello',123,'is my number',{stuff=8181} -- the arguments
)}
-- verify that the echo service works
assert(res[1]=='Hello')
assert(res[2]==123)
assert(res[3]=='is my number')
assert(res[4].stuff==8181)
```

### Run the example
check is zbusd.lua is running! The echo_server.lua will never return (it is a service!) and must be terminated with aisgnal of choice, e.g. kill.

      $ lua examples/echo_server_json.lua &
      $ lua examples/echo_client_json.lua



# How it works

## Broker (zbusd.lua)

Effectively *zbusd.lua* just starts the *zbus broker*. The terms *zbusd* and *broker* are used interchangeably in this context. 

The broker has two jobs: 

- **route zbus-messages** for method calls and notifications
- **provide means for route registration** to allow members to interact with the zbus
- **url pool** for automatic socket assignment

### Routing
The zbus-messages are routed based on their url part (the first part of the multi-part message). The process for notifications and method-calls differs slightly.

#### Notification routing
The broker traverses all registered notification expressions and forwards the complete message to **all** matching routes.

#### Method request routing
The broker traverses all registered method-call expressions and **assures that just one expression matches**. Otherwise the method-call url is ambigouos and an error message is returned In case of a unique match, the complete message is forwarded via the matched route. The response will be routed to the message queue which made the request.

### Registration
zbus members must register routes to subscribe to notifications or to provide services (methods). A route consists of an expression (a [Lua pattern](http://www.lua.org/pil/20.2.html)) and a zeromq-socket-url (aka (zeromq-endpoint)[http://api.zeromq.org/2-1:zmq-connect]). The broker provides a so called **registration socket (default url: "tcp://*:33329", type ZMQ_REP)**, which accepts registration requests. These are the registration calls:

- **url** returns a a free local socket url from the pool
 + params: none
- **replier_open** registers a new (method) replier socket
 + params: url 
- **replier_close** unregisters a previously opened (method) replier socket
 + params: url
- **replier_add** adds an expression to the specified replier socket
 + params: expression,url
- **replier_remove** removes an expression to the specified replier socket
 + params: url,expression
- **listen_open** registers a new (subscribe) listen socket
 + params: url 
- **listen_close** unregisters a previously opened (subscribe) listen socket
 + params: url
- **listen_add** adds an expression to the specified listen socket
 + params: expression,url
- **listen_remove** removes an expression to the specified listen socket
 + params: url,expression

### zbus-registration-request
A zbus-registration-request is a (zeromq) multi-part message with the following layout:

<table border="1">   
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>            
        <tr>		
                <td>1</td><td>method</td><td>replier_add</td>
        </tr>
        <tr>
                <td>2</td><td>arg 1</td><td>tcp://127.0.0.1:8765</td>	
        </tr>
        <tr>
                <td>3</td><td>arg 2</td><td>^echo$</td>	
        </tr>
        <tr>
                <td>n</td><td> ... </td><td> ... </td>	
        </tr>
</table>
The method part (first part) is required, all arguments to registration calls are further parts in the multi-part message.

### zbus-registration-response
A zbus-registration-response is a (zeromq) message. 

**In case of error, it has two parts**:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>result</td><td></td>
        </tr>
        <tr>
                <td>2</td><td>error</td><td>some error message</td>	
        </tr>
</table>

**In case of success, it has one part**:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>result</td><td>tcp://127.0.0.1:8765</td>
        </tr>
</table>

## Method-calls
### method-call-request
The method-call-request message must always be a (zeromq) **two-part message**. The first argument is the method-url to call, the second is an argument string:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>method</td><td>echo</td>
        </tr>
        <tr>
                <td>2</td><td>argument</td><td>[1,111,"hallo"]</td>	
        </tr>
</table>
The format of the **argument and result data can be of any kind** (e.g.,ascii, JSON, binary, etc)! When using zbus/json.lua as zbus.member configuration, the member:call arguments are serialized to JSON arrays.

### method-call-response
The method-call-response message may:
In case of **SUCCESS**, **one** part:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>result</td><td>[1,111,"hallo"]</td>
        </tr>
</table>

In case of a **EXCEPTION** (handler error), it has **two** parts:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>result</td><td></td>
        </tr>
        <tr>
                <td>2</td><td>error</td><td>{error:"something went wrong",code=123}</td>	
        </tr>
</table>

In case of an **zbus/broker error**, it has **three** parts:
<table border="1">      
       <tr>
	<td>Message Part</td><td>Meaning</td><td>Example</td>
       </tr>                     
        <tr>		
                <td>1</td><td>result</td><td></td>
        </tr>
        <tr>
                <td>2</td><td>error</td><td>ERR_AMBIGUOUS</td>	
        </tr>
        <tr>
                <td>3</td><td>error_desc</td><td>method ambiguous: echo</td>	
        </tr>
</table>
