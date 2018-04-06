<cfsetting enablecfoutputonly="true" requesttimeout="10000">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfset qTypes = application.fapi.getContentObjects(typename="asContentType",lProperties="objectid,contentType",orderby="builtToDate asc") />
<cfset contentTypes = "baseline," & listSort(valueList(qTypes.contentType), "textNoCase") />

<cfif structKeyExists(url, "run")>
	<cfset count = 0 />

	<cftry>
		<cfset stResult = bulkFixMetadata(typename=listFirst(url.run), runfrom=listRest(url.run), maxRows=25) />

		<cfset data = {
			"updated"=stResult.updatecount,
			"missing"=stResult.missingcount,
			"typename"=stResult.typename,
			"updateRange"=stResult.range,
			"typelabel"=application.fapi.getContentTypeMetadata(typename=stResult.typename, md="displayname", default=stResult.typename),
			"more"=""
		} />

		<cfif stResult.updatecount or stResult.missingcount>
			<cfset data["updatedTo"] = stResult.nextMark />
		</cfif>

		<cfif stResult.more>
			<cfset data["more"] = stResult.typename & "," & stResult.nextMark />
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
		<cfoutput>
			<a href="##" onClick="$j('##run').val('baseline,start');">Start by setting defaults on all files</a> | 
			<a href="##" onClick="$j('##run').val('#listGetAt(contentTypes, 2)#,1970-01-01T00:00:00Z');">Start at updating content files</a><br>
			<input type='text' name='run' id='run' value='#listGetAt(contentTypes, 2)#,1970-01-01T00:00:00Z' />
		</cfoutput>
		<ft:button value="Start" onClick="startFix(); return false;" />
		<ft:button value="Stop" onClick="stopFix(); return false;" />
		<ft:button value="Clear" onClick="clearLog(); return false;" />
	</ft:buttonPanel>

	<script>
		var status = "stopped";
		var initialRun = "#listGetAt(contentTypes, 2)#,1970-01-01T00:00:00Z";

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
			document.getElementById("run").value = "";
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
					logMessage("" + data.updated + " " + data.typelabel + " records; " + data.missing + " expected files not found " + data.updateRange);
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