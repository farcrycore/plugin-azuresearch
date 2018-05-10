<cfsetting enablecfoutputonly="true" requesttimeout="10000">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfif structKeyExists(url, "run")>
	<cfset count = 0 />

	<cftry>
		<cfset stResult = bulkRemoveFromAzureSearch(objectid=stObj.objectid, maxRows=1000) />

		<cfif stResult.count>
			<cfset application.fapi.stream(type="json", content={
				"uploaded"=stResult.count,
				"typename"=stObj.contentType,
				"description"=stResult.count & " " & application.fapi.getContentTypeMetadata(typename=stObj.contentType, md="displayname", default=stObj.contentType) & " records [" & application.fc.lib.cdn.cdns.azure.dateToRFC3339(stResult.builtToDate_from) & "-" & application.fc.lib.cdn.cdns.azure.dateToRFC3339(stResult.builtToDate) & "]",
				"more"=stResult.count gt 0
			}) />
		</cfif>

		<cfcatch>
			<cfset stError = application.fc.lib.error.normalizeError(cfcatch) />
			<cfset application.fc.lib.error.logData(stError) />
			<cfset application.fapi.stream(type="json", content={ "error"=stError }) />
		</cfcatch>
	</cftry>

	<cfset application.fapi.stream(type="json", content={
		"uploaded"=0,
		"more"=false
	}) />
</cfif>

<cfoutput>
	<h1>Remove #application.fapi.getContentTypeMetadata(stObj.contentType, "displayName", stObj.contentType)# Documents</h1>
	<textarea id="upload-log" style="width:100%" rows=20></textarea>
	<ft:buttonPanel>
		<ft:button value="Start" onClick="startUpload(); return false;" />
		<ft:button value="Stop" onClick="stopUpload(); return false;" />
		<ft:button value="Clear" onClick="clearLog(); return false;" />
	</ft:buttonPanel>

	<script>
		var status = "stopped";

		document.getElementById("upload-log").value = "";
		function logUploadMessage(message, endline) {
			endline = endline || endline === undefined;
			document.getElementById("upload-log").value += message + (endline ? "\n" : "");
		}
		function startUpload() {
			if (status === "stopped") {
				logUploadMessage("Starting ...");
				status = "running";
				runUpload();
			}
		}
		function stopUpload() {
			if (status === "running") {
				logUploadMessage("Stopping ...");
				status = "stopping";
			}
		}
		function clearLog() {
			document.getElementById("upload-log").value = "";
		}

		function runUpload() {
			if (status === "stopping") {
				logUploadMessage("Stopped");
				status = "stopped";
				return;
			}

			logUploadMessage("Removing ... ", false);

			$j.getJSON("#application.fapi.fixURL(addvalues='run=1')#", function(data, textStatus, jqXHR) {
				if (data.error) {
					logUploadMessage(data.error.message);
					logUploadMessage(JSON.stringify(data.error));
					status = "stopped";
				}
				else if (data.more) {
					logUploadMessage(data.description);

					setTimeout(runUpload, 1);
				}
				else {
					logUploadMessage("no more records");
					logUploadMessage("Finished");
					status = "stopped";
				}
			});
		}
	</script>
</cfoutput>

<cfsetting enablecfoutputonly="false">