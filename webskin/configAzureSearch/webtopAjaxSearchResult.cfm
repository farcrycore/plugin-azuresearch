<cfsetting enablecfoutputonly="true">

<cfparam name="url.q" />
<cfparam name="url.f" default="" />
<cfparam name="url.fs" default="" />
<cfparam name="url.m" default="10" />
<cfparam name="url.page" default="1" />

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<cfset stFacets = {} />
<cfloop list="#url.f#" index="thisfacet">
	<cfset stFacets[thisfacet] = "" />
</cfloop>

<cfset stResults = application.fc.lib.azuresearch.search(rawQuery=url.q, facets=stFacets, maxrows=url.m, page=url.page) />

<cfif stResults["@odata.count"] eq 0>
	<cfoutput><div class="alert alert-info">No results were found</div></cfoutput>
<cfelse>
	<cfif structKeyExists(stResults, "facetQueries")>
		<cfoutput><h4>Facets</h4></cfoutput>
		<cfloop collection="#stResults.facetQueries#" item="property">
			<cfset qFacets = stResults.facetQueries[property] />

			<cfoutput>
				<strong>#property#</strong>
				<ul>
					<cfloop query="qFacets">
						<li>#qFacets.value#: #qFacets.count#</li>
					</cfloop>
				</ul>
			</cfoutput>
		</cfloop>
	</cfif>

	<skin:pagination currentPage="#url.page#" recordsPerPage="#url.m#" totalRecords="#stResults['@odata.count']#" query="#stResults.items#" bDisplayTotalRecords="true" r_stObject="item">
		<cfif item.currentrow eq 1>
			<cfoutput>
				<table class="table table-striped">
					<thead>
						<tr>
							<th>Score</th>
							<th>ObjectID</th>
							<th>Typename</th>
							<th>Teaser</th>
						</tr>
					</thead>
					<tbody>
			</cfoutput>
		</cfif>

		<cfoutput>
			<tr>
				<td>#numberFormat(item.score, "0.00")#</td>
				<td>#item.objectid#</td>
				<td>#item.typename#</td>
				<td><skin:view typename="#item.typename#" objectid="#item.objectid#" webskin="displayTeaserStandard" /></td>
			</tr>
		</cfoutput>

		<cfif item.currentrow eq item.recordCount>
			<cfoutput>
					</tbody>
				</table>
			</cfoutput>
		</cfif>
	</skin:pagination>

	<cfdump var="#stResults#">
</cfif>

<cfsetting enablecfoutputonly="true">