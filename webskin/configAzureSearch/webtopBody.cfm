<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />


<ft:processform action="Apply Updates" url="refresh">
	<cfset stIndex = application.fc.lib.azuresearch.getIndex() />
	<cfset qDiffIndexFields = application.fc.lib.azuresearch.diffIndexFields() />
	<cfif reFindNoCase("(^|,)(update|delete)", valueList(qDiffIndexFields.action))>
		<cfset application.fc.lib.azuresearch.deleteIndex() />
		<cfset application.fc.lib.azuresearch.createIndex() />
	<cfelseif arrayLen(stIndex.fields)>
		<cfset application.fc.lib.azuresearch.updateIndex() />
	<cfelse>
		<cfset application.fc.lib.azuresearch.createIndex() />
	</cfif>
	<skin:bubble tags="success" message="Index has been updated" />
</ft:processform>

<cfif structKeyExists(url, "runIndexer")>
	<cfset application.fc.lib.azuresearch.runIndexer(name=url.runIndexer) />
	<skin:bubble tags="success" message="Indexer #url.runIndexer# is running now" />
	<skin:location url="#application.fapi.fixURL(removeValues='runIndexer', addValues='getIndexerStatus=#url.runIndexer#')#" />
</cfif>

<cfif structKeyExists(url, "deleteIndexer")>
	<cfset qIndexer = application.fc.lib.azuresearch.getIndexers(name=url.deleteIndexer) />
	<cfset application.fc.lib.azuresearch.deleteIndexer(name=url.deleteIndexer) />
	<cfset application.fc.lib.azuresearch.deleteDatasource(name=qIndexer.dataSourceName) />
	<skin:bubble tags="success" message="Indexer #url.deleteIndexer# is deleted" />
	<skin:location url="#application.fapi.fixURL(removeValues='deleteIndexer')#" />
</cfif>

<cfif structKeyExists(url, "createIndexer")>
	<cfset qIndexer = application.fc.lib.azuresearch.getExpectedIndexers(name=url.createIndexer) />
	<cfset qDatasource = application.fc.lib.azuresearch.getDatasources(name=qIndexer.dataSourceName) />
	<cfif qDatasource.recordcount neq 0>
		<cfset application.fc.lib.azuresearch.deleteDatasource(name=qIndexer.dataSourceName) />
	</cfif>
	<cfset application.fc.lib.azuresearch.createDatasource(name=qIndexer.dataSourceName, location=qIndexer.location) />
	<cfset application.fc.lib.azuresearch.createIndexer(name=url.createIndexer, description=qIndexer.description, dataSourceName=qIndexer.dataSourceName) />
	<skin:bubble tags="success" message="Indexer #url.createIndexer# is created" />
	<skin:location url="#application.fapi.fixURL(removeValues='createIndexer')#" />
</cfif>

<cfif structKeyExists(url, "updateIndexer")>
	<cfset qIndexer = application.fc.lib.azuresearch.getExpectedIndexers(name=url.updateIndexer) />
	<cfset qDatasource = application.fc.lib.azuresearch.getDatasources(name=qIndexer.dataSourceName) />
	<cfif qDatasource.recordcount eq 0>
		<cfset application.fc.lib.azuresearch.createDatasource(name=qIndexer.dataSourceName, location=qIndexer.location) />
	</cfif>
	<cfset application.fc.lib.azuresearch.updateIndexer(name=url.updateIndexer, description=qIndexer.description, dataSourceName=qIndexer.dataSourceName) />
	<skin:bubble tags="success" message="Indexer #url.updateIndexer# is updated" />
	<skin:location url="#application.fapi.fixURL(removeValues='updateIndexer')#" />
</cfif>


<cfset stIndex = application.fc.lib.azuresearch.getIndex() />

<cfoutput>
	<h1>Azure Search Status</h1>

	<h2>Configuration</h2>
	<table class="table table-striped">
		<cfloop list="servicename,accessKey,index" index="thisfield">
			<tr>
				<th>#application.stCOAPI.configAzureSearch.stProps[thisfield].metadata.ftLabel#</th>
				<td>
					<cfif len(application.fapi.getConfig("azuresearch",thisfield,""))>
						<span class="text-green">Ok</span>
					<cfelse>
						<span class="text-red">Not ok</span>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</table>
</cfoutput>

<cfif application.fc.lib.azuresearch.isEnabled()>
	<cfset qIndexes = application.fc.lib.azuresearch.getIndexes() />
	<cfset qIndexers = application.fc.lib.azuresearch.diffIndexers() />
	<cfset qIndexFields = application.fc.lib.azuresearch.getIndexFields() />
	<cfset qDiffIndexFields = application.fc.lib.azuresearch.diffIndexFields() />

	<cfoutput>
		<h2>Indexes</h2>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Name</th>
				</tr>
			</thead>
			<tbody>
				<cfif not qIndexes.recordcount>
					<tr class="warning"><td colspan="1">No indexes have been set up in Azure</td></tr>
				</cfif>

				<cfloop query="qIndexes">
					<tr>
						<td>
							<cfif qIndexes.name eq application.fapi.getConfig("azuresearch", "index")>
								<strong>#qIndexes.name#</strong>
							<cfelse>
								#qIndexes.name#
							</cfif>
						</td>
					</tr>
				</cfloop>
			</tbody>
		</table>

		<cfset stStatus = {} />
		<cfif structKeyExists(url, "getIndexerStatus")>
			<cfset stStatus = application.fc.lib.azuresearch.getIndexerStatus(name=url.getIndexerStatus) />
		</cfif>

		<h2 id="indexers">Indexers</h2>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Name</th>
					<th>Location</th>
					<th>Container</th>
					<th>Description</th>
					<th>Datasource</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				<cfif not qIndexers.recordcount>
					<tr class="warning"><td colspan="4">No indexers have been set up in Azure</td></tr>
				</cfif>

				<cfloop query="qIndexers">
					<tr>
						<td>#qIndexers.indexer#</td>
						<td>#qIndexers.location#</td>
						<td>#qIndexers.container#</td>
						<td>#qIndexers.description#</td>
						<td>#qIndexers.dataSourceName#</td>
						<td>
							<a href="#application.fapi.fixURL(addvalues='runIndexer=#qIndexers.indexer#')#" title="Run indexer"><i class="fa fa-play"></i></a>
							&nbsp;
							<a href="#application.fapi.fixURL(addvalues='getIndexerStatus=#qIndexers.indexer#')#" title="Get status"><i class="fa fa-tachometer"></i></a>
							&nbsp;
							<cfif qIndexers.action eq "delete">
								<a href="#application.fapi.fixURL(removeValues='getIndexerStatus', addvalues='deleteIndexer=#qIndexers.indexer#')#" title="Unknown indexer" onClick="return window.confirm('Are you sure you want to remove this indexer?');"><i class="fa fa-times"></i></a>
							<cfelseif qIndexers.action eq "add">
								<a href="#application.fapi.fixURL(removeValues='getIndexerStatus', addvalues='createIndexer=#qIndexers.indexer#')#" title="Undeployed indexer"><i class="fa fa-plus"></i></a>
							<cfelseif len(qIndexers.action)>
								<a href="#application.fapi.fixURL(removeValues='getIndexerStatus', addvalues='updateIndexer=#qIndexers.indexer#')#" title="Update indexer: #listRest(qIndexers.action, ':')#"><i class="fa fa-pencil"></i></a>
								<a href="#application.fapi.fixURL(removeValues='getIndexerStatus', addvalues='deleteIndexer=#qIndexers.indexer#')#" title="Remove indexer"><i class="fa fa-times"></i></a>
							<cfelse>
								<a href="#application.fapi.fixURL(removeValues='getIndexerStatus', addvalues='deleteIndexer=#qIndexers.indexer#')#" title="Remove indexer"><i class="fa fa-times"></i></a>
							</cfif>
						</td>
					</tr>
				</cfloop>
			</tbody>
		</table>

		<cfif structKeyExists(url, "getIndexerStatus")>
			<div class="row">
				<div class="span11 offset1">
					<h3>#stStatus.name# (status: #stStatus.status#)</h3>
					<table class="table table-striped">
						<thead>
							<tr>
								<th>Status</th>
								<th>Detail</th>
								<th>Start</th>
								<th>Finish</th>
								<th>Items</th>
							</tr>
						</thead>
						<tbody>
							<cfif not stStatus.runs.recordcount>
								<tr class="warning"><td colspan="5">This indexer has not been executed</td></tr>
							</cfif>

							<cfloop query="stStatus.runs">
								<tr>
									<td>#stStatus.runs.status#</td>
									<td>#stStatus.runs.errorMessage#</td>
									<td>#dateFormat(stStatus.runs.startTime, 'd mmm yyyy')# #timeFormat(stStatus.runs.startTime, 'HH:mm:ss')#</td>
									<td>#dateFormat(stStatus.runs.endTime, 'd mmm yyyy')# #timeFormat(stStatus.runs.endTime, 'HH:mm:ss')#</td>
									<td>#numberFormat(stStatus.runs.itemsProcessed, '0')#</td>
								</tr>
							</cfloop>
						</tbody>
					</table>
				</div>
			</div>
		</cfif>

		<h2>Index Fields</h2>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Field</th>
					<th>Type <a target="_blank" href="http://docs.aws.amazon.com/azuresearch/latest/developerguide/configuring-index-fields.html"><i class="fa fa-question-o"></i></a></th>
					<th>Return</th>
					<th>Searchable</th>
					<th>Filterable</th>
					<th>Facet</th>
					<th>Sort</th>
					<th>Analysis Scheme</th>
				</tr>
			</thead>
			<tbody>
				<cfif not qIndexFields.recordcount>
					<tr class="warning"><td colspan="11">No index fields have been set up in AWS</td></tr>
				</cfif>
				
				<cfloop query="qIndexFields">
					<tr>
						<td>#qIndexFields.field#</td>
						<td>#qIndexFields.type#</td>
						<td>#yesNoFormat(qIndexFields.return)#</td>
						<td>#yesNoFormat(qIndexFields.search)#</td>
						<td>#yesNoFormat(qIndexFields.filter)#</td>
						<td>#yesNoFormat(qIndexFields.facet)#</td>
						<td>#yesNoFormat(qIndexFields.sort)#</td>
						<td>#qIndexFields.analyzer#</td>
					</tr>
				</cfloop>
			</tbody>
		</table>

		<cfif qDiffIndexFields.recordcount>
			<h2>Update Required</h2>

			<cfif reFindNoCase("(^|,)(update|delete)", valueList(qDiffIndexFields.action))>
				<ft:form><ft:button class="btn btn-primary" value="Apply Updates" confirmText="This will require deleting and recreating the index, and you will have to reupload documents. Do you want to continue?" /></ft:form>
			<cfelse>
				<ft:form><ft:button class="btn btn-primary" value="Apply Updates" /></ft:form>
			</cfif>

			<table class="table table-striped">
				<thead>
					<tr>
						<th>Field</th>
						<th>Type <a target="_blank" href="http://docs.aws.amazon.com/azuresearch/latest/developerguide/configuring-index-fields.html"><i class="fa fa-question-o"></i></a></th>
						<th>Return</th>
						<th>Search</th>
						<th>Facet</th>
						<th>Sort</th>
						<th>Analysis Scheme</th>
						<th>Action</th>
					</tr>
				</thead>
				<tbody>
					<cfloop query="qDiffIndexFields">
						<tr>
							<td>#qDiffIndexFields.field#</td>
							<td>#qDiffIndexFields.type#</td>
							<td>#yesNoFormat(qDiffIndexFields.return)#</td>
							<td>#yesNoFormat(qDiffIndexFields.search)#</td>
							<td>#yesNoFormat(qDiffIndexFields.facet)#</td>
							<td>#yesNoFormat(qDiffIndexFields.sort)#</td>
							<td>#qDiffIndexFields.analyzer#</td>
							<td>#qDiffIndexFields.action#</td>
						</tr>
					</cfloop>
				</tbody>
			</table>
		</cfif>
	</cfoutput>
</cfif>

<cfsetting enablecfoutputonly="false">