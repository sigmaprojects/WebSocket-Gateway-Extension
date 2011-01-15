﻿<cfcomponent>

    <cfset state="stopped">

	<cffunction name="init" access="public" output="no" returntype="void">
		<cfargument name="id" required="false" type="string">
		<cfargument name="config" required="false" type="struct">
		<cfargument name="listener" required="false" type="component">

    	<cfset variables.id=id>
        <cfset variables.config=config>
        <cfset variables.listener=listener>

        <cflog text="WebSocket Gateway [#arguments.id#] initialized" type="information" file="WebSocket">

	</cffunction>


	<cffunction name="start" access="public" output="no" returntype="void">
		<cflog text="Starting websocket server on port #variables.config.port#" type="information" file="WebSocket">
        <cftry>
        	<cfset state="starting">

			<cfset variables.server = createObject('java','railo.extension.gateway.websocket.WebSocketServerImpl').init(variables.config.port,variables.id)>
			<cfset variables.server.start()>
         	<cfset state="running">
         	<cflog text="Started websocket server on port #variables.config.port#" type="information" file="WebSocket">
			<cfset startFetcherThread()/>

        	<cfcatch>
            	 <cfset state="failed">
            	 <cflog text="#cfcatch.message#" type="fatal" file="WebSocket">
                 <cfrethrow>
            </cfcatch>
        </cftry>
	</cffunction>

	<cffunction name="stop" access="public" output="no" returntype="void">
		<cflog text="Stopping websocket server on port #variables.config.port#" type="information" file="WebSocket">
        <cftry>
        	<cfset state="stopping">

			<cfset variables.server.stop()>

         	<cfset state="stopped">
         	<cflog text="Stopped websocket server on port #variables.config.port#" type="information" file="WebSocket">
        	<cfcatch>
            	 <cfset state="failed">
            	 <cflog text="#cfcatch.message#" type="fatal" file="WebSocket">
                 <cfrethrow>
            </cfcatch>
        </cftry>
	</cffunction>

	<cffunction name="restart" access="public" output="no" returntype="void">
		<cflog text="Restarting websocket server on port #variables.config.port#" type="information" file="WebSocket">
        <cfif state EQ "running"><cfset stop()></cfif>
		<cfset start()>
	</cffunction>

	<cffunction name="getHelper" access="public" output="no" returntype="any">
	</cffunction>

	<cffunction name="getState" access="public" output="no" returntype="string">
        <cfreturn state>
	</cffunction>

	<cffunction name="getServer" access="public" output="no" returntype="any">
        <cfreturn variables.server>
	</cffunction>

	<cffunction name="sendMessage" access="public" output="no" returntype="string">
		<cfargument name="data" required="false" type="struct">

        <cftry>

            <cfif structKeyExists(data,"webSocketServerAction")>

                <!--- look for a webSocketServerAction (that comes from socket server)--->
                <cfswitch expression="#data.webSocketServerAction#">

                    <!--- Hook for open event . Does not send any message--->
                    <cfcase value="onClientOpen">
                        <cfif len(config.onClientOpen)>
                            <cfset variables.listener[config.onClientOpen](data) >
                        </cfif>
                        <cfreturn>
                    </cfcase>

                    <!--- Hook for close event . Does not send any message--->
                    <cfcase value="onClientClose">
                        <cfif len(config.onClientClose)>
                            <cfset variables.listener[config.onClientClose](data) >
                        </cfif>
                        <cfreturn>
                    </cfcase>

                    <cfcase value="onMessage">
                        <cfif len(config.onMessage)>
                            <cfset variables.listener[config.onMessage](data) >
                        </cfif>
                    </cfcase>

                </cfswitch>

            <!---
            If we get here we are sending message from sendGatewayMessage
            Treat as any incoming message
            --->
            <cfelse>
                <cfif len(config.onMessage)>
                    <cfset variables.listener[config.onMessage](data) >
                </cfif>
            </cfif>

            <!---
            if data.connections.length == 0 >>>> send to all
            else send to the passed connections
             --->
            <cfif not structkeyExists(data,'connections') or not isarray(data.connections)>
                <cflog file="WebSockect" text="send to all #data.message# "/>
                <cfset variables.server.sendToAll(data.message)>
            <cfelse>
                <!--- send only to the provided connections --->
                <cfset variables.server.send(data.connections,data.message)>
            </cfif>

            <cfcatch type="any">
                <cflog type="error" text="#cfcatch.message#" file="WebSocket"/>
                <cfrethrow/>
            </cfcatch>

        </cftry>

	</cffunction>


    <cffunction name="startFetcherThread" access="private" output="false" hint="start the thread that will fetch and process incoming connections">

        <cflog type="information" text="WebSocket Gateway starting fetching messages thread" file="WebSocket"/>

        <cfthread name="_webSocketFetcherThread_#variables.id#" action="run" context="#this#">
            <cftry>
                <cfloop condition="true">
                    <cfset conns = attributes.context.getServer().getConnectionsStack()>
                    <cflog type="information" text="Fetched #conns.size()# messages" file="WebSocket"/>
                    <cfloop array="#conns#" index="conn">
                        <cfset var data = {conn : conn, webSocketServerAction : conn.getType(), message : conn.getMessage()}>
                        <cfset attributes.context.sendMessage(data)>
                        <!--- remove the connection from the queue --->
                        <cfset conns.remove(conn)>
                    </cfloop>
                    <cfset sleep(1000)>
                </cfloop>

                <cfcatch type="any">
                    <cflog type="error" text="#cfcatch.message#" file="WebSocket"/>
                </cfcatch>
            </cftry>
        </cfthread>

    </cffunction>

    <cffunction name="stopFetcherThread" access="private" output="false">

        <cfthread name="_webSocketFetcherThread_#variables.id#" action="terminate"/>

    </cffunction>

</cfcomponent>