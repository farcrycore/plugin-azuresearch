<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />

<cfset stFields = application.fc.lib.azuresearch.getTypeIndexFields() />

<cfoutput>
	<h1>Search</h1>
</cfoutput>

<cfoutput>
	<form method="GET" target="results" action="#application.fapi.getLink(type='configAzureSearch', view='webtopPageModal', bodyView='webtopAjaxSearchResult')#">
		<ft:field label="Query">
			<input type="text" name="q">
		</ft:field>
		<ft:field label="Page size">
			<select name="m">
				<option>5</option>
				<option>10</option>
				<option>20</option>
				<option>50</option>
			</select>
		</ft:field>
		<ft:field label="Facets">
			<select name="f" multiple="true">
				<cfloop collection="#stFields#" item="field">
					<cfif stFields[field].facet>
						<option>#stFields[field].property#</option>
					</cfif>
				</cfloop>
			</select>
		</ft:field>

		<div class="clearfix">
			<button type="submit" class="pull-right btn btn-primary">Search</button>
		</div>
	</form>

	<iframe name="results" style="width:100%;height:1000px;border:0;"></iframe>
</cfoutput>

<cfsetting enablecfoutputonly="false">