<cfsetting enablecfoutputonly="true" requesttimeout="10000">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfset qTypes = application.fapi.getContentObjects(typename="csContentType",lProperties="objectid,contentType",orderby="builtToDate asc") />
<cfset contentTypes = listSort(valueList(qTypes.contentType), "textNoCase") />

<cfif structKeyExists(url, "run")>
	<cfset count = 0 />

	<cftry>
		<cfset stResult = bulkFixMetadata(typename=listFirst(run), runfrom=application.fc.lib.cdn.cdns.azure.rfc3339ToDate(listLast(run)), maxRows=50) />

		<cfset data = {
			"updated"=stResult.updatecount,
			"missing"=stResult.missingcount,
			"typename"=stResult.typename,
			"builtToDate"="",
			"typelabel"=application.fapi.getContentTypeMetadata(typename=stResult.typename, md="displayname", default=stResult.typename),
			"more"=""
		} />

		<cfif stResult.updatecount or stResult.missingcount>
			<cfset data["builtToDate"] = application.fc.lib.cdn.cdns.azure.dateToRFC3339(stResult.builtToDate) />
		</cfif>

		<cfif stResult.more>
			<cfset data["more"] = stResult.typename & "," & application.fc.lib.cdn.cdns.azure.dateToRFC3339(stResult.builtToDate) />
		<cfelseif listFindNoCase(contentTypes, stResult.typename) lt listLen(contentTypes)>
			<cfset data["more"] = listGetAt(contentTypes, listFindNoCase(contentTypes, stResult.typename)+1) & ",1970-01-01T00:00:00.000Z" />
		</cfif>

		<cfset application.fapi.stream(type="json", content=data) />

		<cfcatch>
			<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
			<cfset application.fc.lib.error.logData(stError) />
			<cfset application.fapi.stream(type="json", content={ "error"=stError }) />
		</cfcatch>
	</cftry>

	<cfset application.fapi.stream(type="json", content={
		"updated"=0,
		"more"=""
	}) />
</cfif>

<cfoutput>
	<h1>Fix All Metadata</h1>
	<textarea id="log" style="width:100%" rows=20></textarea>
	<ft:buttonPanel>
		<cfoutput><input type='text' name='run' id='run' value='' /></cfoutput>
		<ft:button value="Start" onClick="startFix(); return false;" />
		<ft:button value="Stop" onClick="stopFix(); return false;" />
		<ft:button value="Clear" onClick="clearLog(); return false;" />
	</ft:buttonPanel>

	<script>
		var status = "stopped";
		var initialRun = "#listFirst(contentTypes)#,1970-01-01T00:00:00.000Z";

		document.getElementById("fix-log").value = "";
		function logMessage(message, endline) {
			endline = endline || endline === undefined;
			document.getElementById("log").value += message + (endline ? "\n" : "");
		}
		function startFix() {
			if (status === "stopped") {
				logMessage("Starting ...");
				status = "running";
				runFix();
			}
		}
		function stopFix() {
			if (status === "running") {
				logMessage("Stopping ...");
				status = "stopping";
			}
		}
		function clearLog() {
			document.getElementById("log").value = "";
		}

		function runFix() {
			if (status === "stopping") {
				logMessage("Stopped");
				status = "stopped";
				return;
			}

			logMessage("Fixing ... ", false);

			var run = $j("##run").val();
			if (run === '') {
				run = initialRun;
			}

			$j.getJSON("#application.fapi.fixURL(addvalues='run=abc')#".replace('run=abc', 'run='+run), function(data, textStatus, jqXHR) {
				if (data.error) {
					logMessage(data.error.message);
					logMessage(JSON.stringify(data.error));
					status = "stopped";
				}
				else if (data.more) {
					logMessage("" + data.updated + " " + data.typelabel + " records; " + data.missing + " expected files not found [" + data.builtToDate + "]");
					$j("##run").val(data.more);
					setTimeout(runFix, 1);
				}
				else {
					logMessage("no more records");
					logMessage("Finished");
					status = "stopped";
				}
			});
		}
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">