<cfscript>
function ashid(string prefix = "")        { return _ashidSingleton().generate(arguments.prefix); }
function ashid4(string prefix = "")       { return _ashidSingleton().generate4(arguments.prefix); }
function parseAshid(required string id)   { return _ashidSingleton().parse(arguments.id); }

private any function _ashidSingleton() {
	if (structKeyExists(request, "ashid"))     return request.ashid;
	if (structKeyExists(application, "ashid")) return application.ashid;
	if (structKeyExists(server, "ashid"))      return server.ashid;
	throw(type="ashid.NotWired", message="No ashid singleton found. Wire one in request/application/server before including helpers.cfm.");
}
</cfscript>
