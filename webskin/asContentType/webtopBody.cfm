<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<ft:processform action="Index 1 Record">
	<cfset stResult = bulkImportIntoAzureSearch(objectid=form.selectedObjectID, maxRows=1) />
	<cfset fullDetail = application.fapi.formatJSON(serializeJSON(stResult)) />

	<skin:loadJS id="formatjson" />
	<skin:htmlHead><cfoutput>
		<style>
			##message-log td, ##message-log th { 
				padding: 5px; 
			}
			##message-log .this-item td {
				background-color: ##dff0d8;
			}
			##message-log .related-item td {
				background-color: ##fcf8e3;
			}
			.formatjson .key {
				color:##a020f0;
			}
			.formatjson .number {
				color:##ff0000;
			}
			.formatjson .string {
				color:##000000;
			}
			.formatjson .boolean {
				color:##ffa500;
			}
			.formatjson .null {
				color:##0000ff;
			}
		</style>
	</cfoutput></skin:htmlHead>
	<skin:bubble tags="success" message="<button class='close' style='margin-right:10px;' type='button' onclick='$j(this).siblings(""pre"").toggle();return false;'><i class='fa fa-info'></i></button> Sent #stResult.count# #application.stCOAPI[stResult.typename].displayname# records to Azure Search. <pre class='formatjson' style='display:none;'>#fullDetail#</pre>" />
</ft:processform>

<ft:processform action="Index Next 10 Records">
	<cfset stResult = bulkImportIntoAzureSearch(objectid=form.selectedObjectID, maxRows=10) />
	<cfset fullDetail = application.fapi.formatJSON(serializeJSON(stResult)) />

	<skin:loadJS id="formatjson" />
	<skin:htmlHead><cfoutput>
		<style>
			##message-log td, ##message-log th { 
				padding: 5px; 
			}
			##message-log .this-item td {
				background-color: ##dff0d8;
			}
			##message-log .related-item td {
				background-color: ##fcf8e3;
			}
			.formatjson .key {
				color:##a020f0;
			}
			.formatjson .number {
				color:##ff0000;
			}
			.formatjson .string {
				color:##000000;
			}
			.formatjson .boolean {
				color:##ffa500;
			}
			.formatjson .null {
				color:##0000ff;
			}
		</style>
	</cfoutput></skin:htmlHead>
	<skin:bubble tags="success" message="<button class='close' style='margin-right:10px;' type='button' onclick='$j(this).siblings(""pre"").toggle();return false;'><i class='fa fa-info'></i></button> Sent #stResult.count# #application.stCOAPI[stResult.typename].displayname# records to Azure Search. <pre class='formatjson' style='display:none;'>#fullDetail#</pre>" />
</ft:processform>


<ft:processform action="Index All Records">
	<cfset stContent = application.fapi.getContentObject(form.selectedobjectid,"asContentType") />
	<cfset contentURL = "#application.url.webroot#/webtop/index.cfm?typename=asContentType&view=webtopPageModal&bodyView=webtopBodyUploadTypeEverything&CONTENTTYPE=#stContent.CONTENTTYPE#">
	<skin:onReady>
		<cfoutput>
			$fc.objectAdminAction('Microsoft Azure Search', '#contentURL#');
		</cfoutput>
	</skin:onReady>		
</ft:processForm>

<ft:processform action="De-index">
	<skin:onReady><cfoutput>
		$fc.objectAdminAction('Remove Documents', '/webtop/index.cfm?typename=asContentType&objectid=#form.selectedobjectid#&view=webtopPageModal&bodyView=webtopBodyRemoveAll');
	</cfoutput></skin:onReady>
</ft:processform>


<cfset aCustomColumns = [
	"contentType",
	"builtToDate",
	{ "title"="Properties", "webskin"="webtopCellProperties" }
] />

<ft:objectAdmin	plugin="azuresearch"
	title="Content Type Indexes"
	typename="asContentType"
	ColumnList="contentType,builtToDate,bDisabled"
	aCustomColumns="#aCustomColumns#"
	SortableColumns=""
	lFilterFields=""
	sqlorderby="contentType asc"
	lCustomActions="Index 1 Record,Index Next 10 Records,Index All Records,De-index"
	r_oTypeAdmin="oTypeAdmin">

	<cfset stAttributes = oTypeAdmin.getAttributes()>
	<cfset arrayappend(stAttributes.aButtons,{
		type="button",
		name="uploadAll",
		value="Upload All Documents",
		class="f-submit",
		buttontype="uyploadAll",
		icon="fa-upload",
		permission="developer",
		onclick="$fc.objectAdminAction('Upload All Documents', '/webtop/index.cfm?typename=asContentType&view=webtopPageModal&bodyView=webtopBodyUploadAll'); return false;"
	}) />
	<cfset arrayappend(stAttributes.aButtons,{
		type="button",
		name="fixFileMetadata",
		value="Fix File Metadata",
		class="f-submit",
		buttontype="fixFileMetadata",
		icon="fa-list",
		permission="developer",
		onclick="$fc.objectAdminAction('Fix File Metadata', '/webtop/index.cfm?typename=asContentType&view=webtopPageModal&bodyView=webtopBodyFixMetadata'); return false;"
	}) />
	<cfset oTypeAdmin.setAttribute("aButtons",stAttributes.aButtons)>

</ft:objectAdmin>

<cfsetting enablecfoutputonly="no">
