<cfcomponent output="false" extends="farcry.core.packages.types.types" displayname="Azure Search Content Type" hint="Manages content type index information" bFriendly="false" bObjectBroker="false" bSystem="true" bRefObjects="true">

	<cfproperty name="contentType" type="nstring" required="true"
		ftSeq="2" ftFieldset="Azure Search Content Type" ftLabel="Content Type"
		ftType="list" ftRenderType="dropdown"
		ftListData="getContentTypes" ftValidation="required"
		ftHint="The content type being indexed.">

	<cfproperty name="builtToDate" type="date" required="false"
		ftSeq="9" ftFieldset="Azure Search Content Type" ftLabel="Built to Date"
		ftType="datetime"
		ftHint="For system use.  Updated by the system.  Used as a reference date of the last indexed item.  Used for batching when indexing items.  Default is blank (no date).">

	<cfproperty name="aProperties" type="array"
		ftSeq="11" ftFieldset="Azure Search Content Type" ftLabel="Properties"
		ftWatch="contentType"
		arrayProps="fieldName:string;fieldType:string;bIndex:boolean;bSort:boolean;bFacet:boolean"
		ftHint="Notes: <ul><li>a literal is a field that is always used for exact matches - as well as UUIDs and arrays, it is also appropriate to use literal for list and status properties</li><li>array field types can be used for array and list properties, which are converted automatically</li><li>int field types do not handle empty values (i.e. null) - those properties must be a valid integer</ul>">


	<cffunction name="AfterSave" access="public" output="false" returntype="struct" hint="Called from setData and createData and run after the object has been saved.">
		<cfargument name="stProperties" required="yes" type="struct" hint="A structure containing the contents of the properties that were saved to the object.">

		<cfset application.fc.lib.azuresearch.updateTypeIndexFieldCache(typename=arguments.stProperties.typename) />
		<cfset application.fc.lib.azuresearch.updateTypeIndexFieldCache() />

		<cfreturn super.aftersave(argumentCollection = arguments) />
	</cffunction>

	<cffunction name="onDelete" returntype="void" access="public" output="false" hint="Is called after the object has been removed from the database">
		<cfargument name="typename" type="string" required="true" hint="The type of the object" />
		<cfargument name="stObject" type="struct" required="true" hint="The object" />

		<cfset application.fc.lib.azuresearch.updateTypeIndexFieldCache(typename=arguments.typename) />

		<cfset super.onDelete(argumentCollection = arguments) />
	</cffunction>

	<cffunction name="ftValidateContentType" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="objectid" required="true" type="string" hint="The objectid of the object that this field is part of.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">

		<cfset var stResult = structNew()>
		<cfset var oField = createObject("component", "farcry.core.packages.formtools.field") />
		<cfset var qDupeCheck = "" />

		<!--- required --->
		<cfif NOT len(stFieldPost.Value)>
			<cfreturn oField.failed(value=arguments.stFieldPost.value, message="This is a required field.") />
		</cfif>

		<!--- check for duplicates --->
		<cfset qDupeCheck = application.fapi.getContentObjects(typename="asContentType",contentType_eq=trim(arguments.stFieldPost.value),objectid_neq=arguments.objectid) />
		<cfif qDupeCheck.recordCount gt 0>
			<cfreturn oField.failed(value=arguments.stFieldPost.value, message="There is already a configuration created for this content type.") />
		</cfif>

		<cfreturn oField.passed(value=arguments.stFieldPost.Value) />
	</cffunction>

	<cffunction name="getContentTypes" access="public" hint="Get list of all searchable content types." output="false" returntype="query">
		<cfset var listdata = "" />
		<cfset var qListData = queryNew("typename,displayname") />
		<cfset var type = "" />

		<cfloop collection="#application.types#" item="type">
			<cfif not application.stCOAPI[type].bSystem>
				<cfset queryAddRow(qListData) />
				<cfset querySetCell(qListData, "typename", type) />
				<cfset querySetCell(qListData, "displayname", "#application.stcoapi[type].displayname# (#type#)") />
			</cfif>
		</cfloop>

		<cfquery dbtype="query" name="qListData">
			SELECT typename as value, displayname as name FROM qListData ORDER BY displayname
		</cfquery>

		<cfreturn qListData />
	</cffunction>

	<cffunction name="ftEditAProperties" access="public" output="false" returntype="string" hint="This is going to called from ft:object and will always be passed 'typename,stobj,stMetadata,fieldname'.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stObject" required="true" type="struct" hint="The object of the record that this field is part of.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">
		<cfargument name="fieldname" required="true" type="string" hint="This is the name that will be used for the form field. It includes the prefix that will be used by ft:processform.">

		<cfset var joinItems = "" />
		<cfset var i = "" />
		<cfset var j = 0 />
		<cfset var returnHTML = "" />
		<cfset var thisobject = "" />
		<cfset var qFields = querynew("empty") />
		<cfset var qTypes = application.fc.lib.azuresearch.getFieldTypes() />
		<cfset var aCurrent = arguments.stMetadata.value />

		<cfif issimplevalue(aCurrent)>
			<cfif len(aCurrent)>
				<cfset aCurrent = deserializeJSON(aCurrent) />
			<cfelse>
				<cfset aCurrent = [] />
			</cfif>
		</cfif>

		<cfif len(arguments.stObject.contentType) and structKeyExists(application.stCOAPI,arguments.stObject.contentType)>
			<cfset qFields = getTypeFields(arguments.stObject.contentType, aCurrent) />
			<cfset updateProperties(arguments.stObject.contentType, aCurrent) />
		</cfif>

		<cfsavecontent variable="returnHTML"><cfoutput>
			<input type="hidden" name="#arguments.fieldname#" value="#application.fc.lib.esapi.encodeForHTMLAttribute(serializeJSON(aCurrent))#" />

			<table class="table">
				<thead>
					<tr>
						<th>Index</th>
						<th>Field</th>
						<th>Type <a target="_blank" href="https://docs.microsoft.com/en-us/rest/api/searchservice/supported-data-types"><i class="fa fa-question-o"></i></a></th>
						<th>Sortable</th>
						<th>Facetable</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					<cfif not arraylen(aCurrent) or not len(arguments.stObject.contentType) or not structKeyExists(application.stCOAPI,arguments.stObject.contentType)>
						<tr class="warning"><td colspan="6">Please select a valid content type</td></tr>
					</cfif>

					<cfloop from="1" to="#arraylen(aCurrent)#" index="i">
						<cfset thisobject = aCurrent[i] />

						<tr <cfif thisobject.bIndex>class="success"</cfif>>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bIndex#i#" value="1" <cfif thisobject.bIndex>checked</cfif> onchange="$j(this).closest('tr').toggleClass('success');" />
								<input type="hidden" name="#arguments.fieldname#bIndex#i#" value="0" />
							</td>
							<td>
								<input type="hidden" name="#arguments.fieldname#field#i#" value="#thisobject.fieldName#" />
								<cfloop query="qFields">
									<cfif qFields.field eq thisobject.fieldName>
										<span title="#qFields.field#">#qFields.label# <small><code>#qFields.field#</code></small><br>
										<small>#application.fapi.getPropertyMetadata(typename=arguments.stObject.contentType, property=qFields.field, md="ftFieldset", default="")#</small>
									</span>
								</cfif>
								</cfloop>
							</td>
							<td>
								<select name="#arguments.fieldname#type#i#" style="width:auto;min-width:0;">
									<cfloop query="qTypes">
										<option value="#qTypes.code#" <cfif qTypes.code eq thisobject.fieldType>selected</cfif>>#qTypes.label#</option>
									</cfloop>
								</select>
							</td>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bSort#i#" value="1" <cfif thisobject.bSort>checked</cfif> />
								<input type="hidden" name="#arguments.fieldname#bSort#i#" value="0" />
							</td>
							<td>
								<input type="checkbox" name="#arguments.fieldname#bFacet#i#" value="1" <cfif thisobject.bFacet>checked</cfif> />
								<input type="hidden" name="#arguments.fieldname#bFacet#i#" value="0" />
							</td>
							<td>
								<a href="##" onclick="$j(this).closest('tr').remove(); return false;"><i class="fa fa-times"></i></a>
							</td>
						</tr>
					</cfloop>
				</tbody>
			</table>
		</cfoutput></cfsavecontent>

		<cfreturn returnHTML />
	</cffunction>

	<cffunction name="ftValidateAProperties" access="public" output="true" returntype="struct" hint="This will return a struct with bSuccess and stError">
		<cfargument name="objectid" required="true" type="string" hint="The objectid of the object that this field is part of.">
		<cfargument name="typename" required="true" type="string" hint="The name of the type that this field is part of.">
		<cfargument name="stFieldPost" required="true" type="struct" hint="The fields that are relevent to this field type.">
		<cfargument name="stMetadata" required="true" type="struct" hint="This is the metadata that is either setup as part of the type.cfc or overridden when calling ft:object by using the stMetadata argument.">

		<cfset var aCurrent = deserializeJSON(arguments.stFieldPost.value) />
		<cfset var i = 0 />
		<cfset var aNew = [] />

		<cfloop from="1" to="#arraylen(aCurrent)#" index="i">
			<cfif structKeyExists(arguments.stFieldPost.stSupporting,"field#i#") and listfirst(arguments.stFieldPost.stSupporting["bIndex#i#"]) eq "1">
				<cfset arrayAppend(aNew,{
					"data" = arguments.stFieldPost.stSupporting["field#i#"],
					"fieldName" = arguments.stFieldPost.stSupporting["field#i#"],
					"fieldType" = arguments.stFieldPost.stSupporting["type#i#"],
					"bIndex" = listfirst(arguments.stFieldPost.stSupporting["bIndex#i#"]),
					"bSort" = listfirst(arguments.stFieldPost.stSupporting["bSort#i#"]),
					"bFacet" = listfirst(arguments.stFieldPost.stSupporting["bFacet#i#"])
				}) />
			</cfif>
		</cfloop>

		<cfreturn application.formtools.field.oFactory.passed(aNew) />
	</cffunction>

	<cffunction name="getTypeFields" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="aCurrent" type="array" required="true" />

		<cfset var qMetadata = application.stCOAPI[arguments.typename].qMetadata />
		<cfset var stField = {} />
		<cfset var oType = application.fapi.getContentType(arguments.typename) />
		<cfset var qResult = "" />

		<!--- Actual properties --->
		<cfquery dbtype="query" name="qMetadata">
			select 		propertyname as field, '' as label, ftType as type, ftSeq
			from 		qMetadata
			where 		lower(propertyname) <> 'objectid'
			order by 	ftSeq, propertyname
		</cfquery>
		<cfloop query="qMetadata">
			<cfset querySetCell(qMetadata, "label", application.fapi.getPropertyMetadata(arguments.typename,qMetadata.field,"ftLabel",qMetadata.field), qMetadata.currentrow) />
			<cfset querySetCell(qMetadata, "type", application.fc.lib.azuresearch.getDefaultFieldType(application.stCOAPI[arguments.typename].stProps[qMetadata.field].metadata), qMetadata.currentrow) />
		</cfloop>

		<!--- Generated properties --->
		<cfset qResult = getGeneratedProperties(arguments.typename) />
		<cfloop query="qResult">
			<cfif not listFindNoCase(valuelist(qMetadata.field),qResult.field)>
				<cfset queryAddRow(qMetadata) />
				<cfset querySetCell(qMetadata, "field", qResult.field) />
				<cfset querySetCell(qMetadata, "label", "#qResult.label#") />
				<cfset querySetCell(qMetadata, "type", qResult.type) />
				<cfset querySetCell(qMetadata, "ftSeq", arraymax(listToArray(valuelist(qMetadata.ftSeq)))+1) />
			</cfif>
		</cfloop>

		<!--- Missing properties --->
		<cfloop array="#arguments.aCurrent#" index="stField">
			<cfif not listFindNoCase(valuelist(qMetadata.field),stField.fieldName)>
				<cfset queryAddRow(qMetadata) />
				<cfset querySetCell(qMetadata,"field",stField.fieldName) />
				<cfset querySetCell(qMetadata,"label","#stField.fieldName# [INVALID]") />
				<cfset querySetCell(qMetadata,"type","string") />
				<cfset querySetCell(qMetadata,"ftSeq",arraymax(listToArray(valuelist(qMetadata.ftSeq)))+1) />
			</cfif>
		</cfloop>

		<cfreturn qMetadata />
	</cffunction>

	<cffunction name="updateProperties" access="public" output="false" returntype="void">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="aCurrent" type="array" required="true" />

		<cfset var existingProperties = "" />
		<cfset var i = 0 />
		<cfset var qFields = "" />
		<cfset var qMetadata = "" />

		<cfset var stField = {} />

		<cfif len(arguments.typename) and structKeyExists(application.stCOAPI,arguments.typename)>
			<cfset qMetadata = getGeneratedProperties(arguments.typename) />

			<cfloop from="#arraylen(arguments.aCurrent)#" to="1" index="i" step="-1">
				<cfif structKeyExists(application.stCOAPI[arguments.typename].stProps, arguments.aCurrent[i].fieldName) or listFindNoCase(valuelist(qMetadata.field), arguments.aCurrent[i].fieldName)>
					<cfset existingProperties = listappend(existingProperties,arguments.aCurrent[i].fieldName) />
				<cfelseif not arguments.aCurrent[i].bIndex>
					<cfset arrayDeleteAt(arguments.aCurrent,i) />
				</cfif>
			</cfloop>

			<!--- Generated properties --->
			<cfloop query="qMetadata">
				<cfif not listFindNoCase(existingProperties,qMetadata.field)>
					<cfset arrayappend(arguments.aCurrent, {
						"fieldName" = qMetadata.field,
						"fieldType" = qMetadata.type,
						"bIndex" = 0,
						"bSort" = 0,
						"bFacet" = 0
					}) />
				</cfif>
			</cfloop>

			<!--- Actual properties --->
			<cfset qMetadata = application.stCOAPI[arguments.typename].qMetadata />
			<cfloop query="qMetadata">
				<cfif not listFindNoCase(existingProperties,qMetadata.propertyname)>
					<cfset arrayappend(arguments.aCurrent, {
						"fieldName" = qMetadata.propertyname,
						"fieldType" = application.fc.lib.azuresearch.getDefaultFieldType(application.stCOAPI[arguments.typename].stProps[qMetadata.propertyname].metadata),
						"bIndex" = 0,
						"bSort" = 0,
						"bFacet" = 0
					}) />
				</cfif>
			</cfloop>
		</cfif>

	</cffunction>

	<cffunction name="getIndexFields" access="public" output="false" returntype="query">
		<cfargument name="typename" required="false" type="string" />

		<cfset var qResult = "" />

		<cfswitch expression="#application.dbtype#">
			<cfcase value="mssql,mssql2005,mssql2012">
				<cfquery datasource="#application.dsn#" name="qResult">
					select 	p.fieldName as property,
							lower(p.fieldName) + '_' + lower(p.fieldType) as field,
							p.fieldType as 'type', p.bSort as 'sort', p.bFacet as 'facet',
							0 as 'return', 1 as 'search', case when p.fieldType in ('String','CollectionString') then 0 else 1 end as 'filter', case when p.fieldType in ('Literal','CollectionLiteral') then 'keyword' when p.fieldType in ('String','CollectionString') then 'standard' else '' end as analyzer
					from 	asContentType ct
							inner join
							asContentType_aProperties p
							on ct.objectid=p.parentid
					where 	p.bIndex=1
							<cfif structKeyExists(arguments,"typename")>
								and ct.contentType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
							</cfif>
				</cfquery>
			</cfcase>

			<cfdefaultcase>
				<cfquery datasource="#application.dsn#" name="qResult">
					select 	p.fieldName as property, concat(lower(p.fieldName),'_',lcase(p.fieldType)) as field, p.fieldType as `type`, p.bSort as `sort`, p.bFacet as `facet`,
							0 as `return`, 1 as `search`, case when p.fieldType in ('String','CollectionString') then 0 else 1 end as 'filter', case when p.fieldType in ('Literal','CollectionLiteral') then 'keyword' when p.fieldType in ('String','CollectionString') then 'standard' else '' end as analyzer
					from 	asContentType ct
							inner join
							asContentType_aProperties p
							on ct.objectid=p.parentid
					where 	p.bIndex=1
							<cfif structKeyExists(arguments,"typename")>
								and ct.contentType = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
							</cfif>
				</cfquery>
			</cfdefaultcase>
		</cfswitch>

		<cfif qResult.recordcount>
			<cfset queryAddRow(qResult) />
			<cfset querySetCell(qResult,"property","objectid") />
			<cfset querySetCell(qResult,"field","objectid_literal") />
			<cfset querySetCell(qResult,"type","Literal") />
			<cfset querySetCell(qResult,"return",1) />
			<cfset querySetCell(qResult,"search",1) />
			<cfset querySetCell(qResult,"filter",1) />
			<cfset querySetCell(qResult,"facet",0) />
			<cfset querySetCell(qResult,"sort",0) />
			<cfset querySetCell(qResult,"analyzer","keyword") />

			<cfset queryAddRow(qResult) />
			<cfset querySetCell(qResult,"property","typename") />
			<cfset querySetCell(qResult,"field","typename_literal") />
			<cfset querySetCell(qResult,"type","Literal") />
			<cfset querySetCell(qResult,"return",1) />
			<cfset querySetCell(qResult,"search",1) />
			<cfset querySetCell(qResult,"filter",1) />
			<cfset querySetCell(qResult,"facet",1) />
			<cfset querySetCell(qResult,"sort",0) />
			<cfset querySetCell(qResult,"analyzer","keyword") />

			<cfset queryAddRow(qResult) />
			<cfset querySetCell(qResult,"property","filecontent") />
			<cfset querySetCell(qResult,"field","filecontent_string") />
			<cfset querySetCell(qResult,"type","String") />
			<cfset querySetCell(qResult,"return",0) />
			<cfset querySetCell(qResult,"search",1) />
			<cfset querySetCell(qResult,"filter",0) />
			<cfset querySetCell(qResult,"facet",0) />
			<cfset querySetCell(qResult,"sort",0) />
			<cfset querySetCell(qResult,"analyzer","standard") />
		</cfif>

		<cfreturn qResult />
	</cffunction>

	<cffunction name="getGeneratedProperties" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />

		<cfset var qResult = querynew("field,label,type") />
		<cfset var prop = "" />
		<cfset var oType = application.fapi.getContentType(arguments.typename) />

		<!--- If there is a function in the type for this property, use that instead of the default --->
		<cfif structKeyExists(oType,"getAzureSearchGeneratedProperties")>
			<cfinvoke component="#oType#" method="getAzureSearchGeneratedProperties" returnvariable="qResult">
				<cfinvokeargument name="typename" value="#arguments.typename#" />
			</cfinvoke>
		<cfelse>
			<cfif not structKeyExists(application.stCOAPI[arguments.typename].stProps, "status")>
				<cfset queryAddRow(qResult) />
				<cfset querySetCell(qResult, "field", "status") />
				<cfset querySetCell(qResult, "label", "Status") />
				<cfset querySetCell(qResult, "type", "Literal") />
			</cfif>

			<cfloop collection="#application.stCOAPI[arguments.typename].stProps#" item="prop">
				<cfif application.fapi.getPropertyMetadata(arguments.typename, prop, "type") eq "date">
					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyy") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Year)") />
					<cfset querySetCell(qResult, "type", "Literal") />

					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyymmm") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Month)") />
					<cfset querySetCell(qResult, "type", "Literal") />

					<cfset queryAddRow(qResult) />
					<cfset querySetCell(qResult, "field", prop & "_yyyymmmdd") />
					<cfset querySetCell(qResult, "label", application.fapi.getPropertyMetadata(arguments.typename, prop, "ftLabel", prop) & " (Day)") />
					<cfset querySetCell(qResult, "type", "Literal") />
				</cfif>
			</cfloop>
		</cfif>

		<cfreturn qResult />
	</cffunction>

	<cffunction name="getUploadMetadata" access="public" output="false" returntype="struct">
		<cfargument name="typename" type="string" required="true" />

		<cfset var stResult = {} />
		<cfset var property = "" />
		<cfset var stMetadata = "" />
		<cfset var fileMeta = "" />

		<cfloop collection="#application.stCOAPI[arguments.typename].stProps#" item="property">
			<cfif application.fapi.getPropertyMetadata(arguments.typename, property, "ftType", "") eq "azureupload"
				or application.fapi.getPropertyMetadata(arguments.typename, property, "ftType", "") eq "file">

				<cfset stMetadata = application.stCOAPI[arguments.typename].stProps[property].metadata />
				<cfset fileMeta = application.fc.lib.azurecdn.resolveLocationMetadata(typename=arguments.typename, stMetadata=stMetadata) />

				<cfif not structIsEmpty(fileMeta)>
					<cfset stResult[property] = stMetadata />
				</cfif>
			</cfif>
		</cfloop>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="getRecordsToUpdate" access="public" output="false" returntype="query">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="builtToDate" type="string" required="false" />
		<cfargument name="builtToID" type="uuid" required="false" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />
		<cfargument name="extraProperties" type="string" required="false" default="" />

		<cfset var qContent = "" />

		<cfquery datasource="#application.dsn#" name="qContent" maxrows="#arguments.maxrows#">
			select 		t.objectid, t.datetimeLastUpdated, datePart(ms, t.datetimeLastUpdated) as datetimeLastUpdated_ms, '#arguments.typename#' as typename, 'updated' as operation
						<cfif len(arguments.extraProperties)>
							, #arguments.extraProperties#
						</cfif>
			<cfif structKeyExists(arguments, "builtToDate") and application.fapi.showFarcryDate(arguments.builtToDate)>
				from	#application.dbowner##arguments.typename# t
				where 	t.datetimeLastUpdated > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.builtToDate#">
			<cfelseif structKeyExists(arguments, "builtToID")>
				from	#application.dbowner##arguments.typename# t
						inner join #application.dbowner#asContentType c on c.contentType=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
				where	t.datetimeLastUpdated > c.builtToDate
			</cfif>

			UNION

			select 		t.archiveID as objectid, t.datetimeCreated as datetimeLastUpdated, datePart(ms, t.datetimeCreated) as datetimeLastUpdated_ms, '#arguments.typename#' as typename, 'deleted' as operation
						<cfif len(arguments.extraProperties)>
							, '' as #replace(arguments.extraProperties, ",", ", '' as ", "ALL")#
						</cfif>
			<cfif structKeyExists(arguments, "builtToDate") and application.fapi.showFarcryDate(arguments.builtToDate)>
				from	#application.dbowner#dmArchive
				where	objectTypename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#" />
						and bDeleted = <cfqueryparam cfsqltype="cf_sql_bit" value="1" />
						<cfif application.fapi.showFarcryDate(arguments.builtToDate)>
							and datetimeLastUpdated > <cfqueryparam cfsqltype="cf_sql_timestamp" value="#arguments.builtToDate#">
						</cfif>
			<cfelseif structKeyExists(arguments, "builtToID")>
				from	#application.dbowner#dmArchive t
						inner join #application.dbowner#asContentType c on c.contentType=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#">
				where	t.objectTypename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.typename#" />
						and t.bDeleted = <cfqueryparam cfsqltype="cf_sql_bit" value="1" />
						and t.datetimeLastUpdated > c.builtToDate
			</cfif>

			order by 	datetimeLastUpdated asc
		</cfquery>

		<cfreturn qContent />
	</cffunction>

	<cffunction name="bulkImportIntoAzureSearch" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" hint="The objectid of the asContentType record to import" />
		<cfargument name="stObject" type="struct" required="false" hint="The asContentType object to import" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />
		<cfargument name="requestSize" type="numeric" required="false" default="5000000" />

		<cfset var qContent = "" />
		<cfset var oContent = "" />
		<cfset var stObject = "" />
		<cfset var stContent = {} />
		<cfset var aDocs = [] />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />
		<cfset var count = 0 />

		<cfimport taglib="/farcry/core/tags/farcry" prefix="fc" />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = getData(objectid=arguments.objectid) />
		</cfif>

		<cfset oContent = application.fapi.getContentType(typename=arguments.stObject.contentType) />
		<cfset qContent = getRecordsToUpdate(typename=arguments.stObject.contentType, builtToID=arguments.stObject.objectid, maxRows=arguments.maxRows) />
		<cfset builtToDate = arguments.stObject.builtToDate />

		<cfloop query="qContent">
			<cfif qContent.operation eq "updated" and (not structKeyExists(oContent, "isIndexable") or oContent.isIndexable(stObject=stObject))>
				<cfset stObject = oContent.getData(objectid=qContent.objectid) />
				<cfset stContent = getAzureSearchDocument(stObject=stObject) />
				<cfset stContent["@search.action"] = "mergeOrUpload" />
				<cfset arrayAppend(aDocs, stContent) />

				<fc:logevent object="#stObject.objectid#" type="#stObject.typename#" event="searchindexed" />
			<cfelseif qContent.operation eq "deleted">
				<cfset arrayAppend(aDocs, {
					"@search.action" = "delete",
					"objectid_literal" = qContent.objectid
				}) />

				<fc:logevent object="#stObject.objectid#" type="#stObject.typename#" event="searchdeleted" />
			</cfif>

			<cfset builtToDate = qContent.datetimeLastUpdated />
		</cfloop>

		<cfif arrayLen(aDocs)>
			<cfset stResult = application.fc.lib.azuresearch.uploadDocuments(documents=aDocs) />
			<cfset arguments.stObject.builtToDate = builtToDate />
			<cfset setData(stProperties=arguments.stObject) />
			<cflog file="azuresearch" text="Updated #arrayLen(aDocs)# #arguments.stObject.contentType# record/s" />
		</cfif>

		<cfset stResult["typename"] = arguments.stObject.contentType />
		<cfset stResult["count"] = arrayLen(aDocs) />
		<cfset stResult["builtToDate"] = builtToDate />

		<cfreturn stResult />
	</cffunction>

	<cffunction name="bulkFixMetadata" access="public" output="false" returntype="struct">
		<cfargument name="typename" type="string" required="true" />
		<cfargument name="runfrom" type="any" required="true" />
		<cfargument name="maxRows" type="numeric" required="false" default="-1" />

		<cfset var oContent = {} />
		<cfset var stObject = "" />
		<cfset var stContent = {} />
		<cfset var aDocs = [] />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />
		<cfset var updatecount = 0 />
		<cfset var missingcount = 0 />
		<cfset var stUploadMetadata = {} />
		<cfset var qContent = [] />
		<cfset var stMetadata = {} />
		<cfset var key = "" />
		<cfset var fileMeta = {} />

		<!--- The baseline run through - set default metadata on every file in the location --->
		<cfif arguments.typename eq "baseline">
			<cfset stFiles = application.fc.lib.azurecdn.getAllFiles(marker=arguments.runfrom, maxrows=arguments.maxrows) />

			<cfloop query="stFiles.files">
				<cfset stMeta = application.fc.lib.cdn.cdns.azure.ioReadMetadata(config=stFiles.locationConfig, file=stFiles.files.file) />
				<cfif not structKeyExists(stMeta, "AzureSearch_Skip")>
					<cfset application.fc.lib.cdn.cdns.azure.ioWriteMetadata(
						config = stFiles.locationConfig,
						file = stFiles.files.file,
						metadata = {
							"AzureSearch_Skip" = "true"
						}
					) />
				</cfif>
			</cfloop>

			<cfreturn {
				"typename" = "baseline",
				"updatecount" = stFiles.files.recordcount,
				"missingcount" = 0,
				"nextMark" = stFiles.nextMarker,
				"more" = stFiles.files.recordcount eq arguments.maxrows,
				"range" = "[" & listFirst(runfrom) & "]"
			} />
		</cfif>

		<!--- There are no azure file properties marked for indexing --->
		<cfset oContent = application.fapi.getContentType(typename=arguments.typename) />
		<cfset stUploadMetadata = getUploadMetadata(arguments.typename) />
		<cfif structIsEmpty(stUploadMetadata)>
			<!--- There are no indexable file properties --->
			<cfreturn {
				"typename"=arguments.typename,
				"updatecount"=0,
				"missingcount"=0,
				"more"=false,
				"range"=""
			} />
		</cfif>

		<!--- Based on DB records, update the metadata on the files for this type --->
		<cfset arguments.runfrom = application.fc.lib.cdn.cdns.azure.rfc3339ToDate(arguments.runfrom) />
		<cfset qContent = getRecordsToUpdate(typename=arguments.typename, builtToDate=arguments.runfrom, maxRows=arguments.maxRows, extraProperties=structKeyList(stUploadMetadata)) />

		<cfloop query="qContent">
			<cfloop collection="#stUploadMetadata#" item="key">
				<cfif len(qContent[key][qContent.currentrow])>
					<cftry>
						<cfset stObject = oContent.getData(qContent.objectid) />
						<cfset fileMeta = application.fc.lib.azurecdn.resolveLocationMetadata(typename=arguments.typename, stObject=stObject, stMetadata=stUploadMetadata[key]) />
						<cfset stMeta = application.fc.lib.cdn.cdns.azure.ioReadMetadata(config=fileMeta.cdnConfig, file=stObject[stUploadMetadata[key].name]) />
						<cfif not structKeyExists(stMeta, "AzureSearch_Skip") or stMeta.AzureSearch_Skip eq "true">
							<cfset application.fc.lib.azurecdn.updateTags(typename=arguments.typename, stObject=oContent.getData(qContent.objectid), stMetadata=stUploadMetadata[key]) />
						</cfif>
						<cfset updatecount += 1 />

						<cfcatch>
							<cfif find("The specified blob does not exist", cfcatch.message) or find("The requested URI does not represent any resource on the server.", cfcatch.message)>
								<cfset missingcount += 1 />
							<cfelse>
								<cfrethrow />
							</cfif>
						</cfcatch>
					</cftry>
				</cfif>
			</cfloop>

			<cfset builtToDate = qContent.datetimeLastUpdated />
		</cfloop>

		<cfreturn {
			"typename" = arguments.typename,
			"updatecount" = updatecount,
			"missingcount" = missingcount,
			"builtToDate" = builtToDate,
			"nextMark" = qContent.recordcount ? application.fc.lib.cdn.cdns.azure.dateToRFC3339(builtToDate) : "",
			"more" = qContent.recordcount eq arguments.maxrows,
			"range" = "[" & application.fc.lib.cdn.cdns.azure.dateToRFC3339(arguments.runfrom) & " - " & (qContent.recordcount ? application.fc.lib.cdn.cdns.azure.dateToRFC3339(builtToDate) : "now") & "]"
		} />
	</cffunction>

	<cffunction name="importIntoAzureSearch" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" hint="The objectid of the content to import" />
		<cfargument name="typename" type="string" required="false" hint="The typename of the content to import" />
		<cfargument name="stObject" type="struct" required="false" hint="The content object to import" />
		<cfargument name="operation" type="string" required="true" hint="updated or deleted" />

		<cfset var oContent = "" />
		<cfset var aDocs = [] />
		<cfset var builtToDate = "" />
		<cfset var stResult = {} />

		<cfimport taglib="/farcry/core/tags/farcry" prefix="fc" />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = application.fapi.getContentData(typename=arguments.typename,objectid=arguments.objectid) />
		</cfif>

		<cfset oContent = application.fapi.getContentType(typename=arguments.stObject.typename) />

		<cfif arguments.operation eq "updated">
			<cfset stContent = getAzureSearchDocument(stObject=arguments.stObject) />
			<cfset stContent["@search.action"] = "mergeOrUpload" />
			<cfset arrayAppend(aDocs, stContent) />
			<cfset builtToDate = arguments.stObject.datetimeLastUpdated />
			<fc:logevent object="#arguments.stObject.objectid#" type="#arguments.stObject.typename#" event="searchindexed" />
		<cfelseif arguments.operation eq "deleted">
			<cfset arrayAppend(aDocs, {
				"@search.action" = "delete",
				"objectid_literal" = arguments.stObject.objectid
			}) />
			<cfset builtToDate = now() />
			<fc:logevent object="#arguments.stObject.objectid#" type="#arguments.stObject.typename#" event="searchdeleted" />
		</cfif>

		<cfset stResult = application.fc.lib.azuresearch.uploadDocuments(documents=aDocs) />
		<cfquery datasource="#application.dsn#">
			update 	#application.dbowner#asContentType
			set 	builtToDate=<cfqueryparam cfsqltype="cf_sql_timestamp" value="#builtToDate#" />
			where 	contentType=<cfqueryparam cfsqltype="cf_sql_varchar" value="#arguments.stObject.typename#" />
		</cfquery>
		<cflog file="azuresearch" text="Updated 1 #arguments.stObject.typename# record/s" />

		<cfset stResult["typename"] = arguments.stObject.typename />
		<cfset stResult["count"] = 1 />
		<cfset stResult["builtToDate"] = builtToDate />

		<cfreturn stResult />
	</cffunction>

	<cffunction name="getAzureSearchDocument" access="public" output="false" returntype="struct">
		<cfargument name="objectid" type="uuid" required="false" />
		<cfargument name="typename" type="string" required="false" />
		<cfargument name="stObject" type="struct" required="false" />

		<cfset var stFields = "" />
		<cfset var field = "" />
		<cfset var property = "" />
		<cfset var stResult = {} />
		<cfset var item = "" />
		<cfset var oType = "" />
		<cfset var i = 0 />

		<cfif not structKeyExists(arguments,"stObject")>
			<cfset arguments.stObject = application.fapi.getContentObject(typename=arguments.typename,objectid=arguments.objectid) />
		</cfif>

		<cfset oType = application.fapi.getContentType(arguments.stObject.typename) />

		<cfset stFields = application.fc.lib.azuresearch.getTypeIndexFields(arguments.stObject.typename) />

		<cfloop collection="#stFields#" item="field">
				<cfset property = stFields[field].property />
				<!--- If there is a function in the type for this property, use that instead of the default --->
				<cfif structKeyExists(oType,"getAzureSearch#property#")>
					<cfinvoke component="#oType#" method="getAzureSearch#property#" returnvariable="item">
						<cfinvokeargument name="stObject" value="#arguments.stObject#" />
						<cfinvokeargument name="property" value="#property#" />
						<cfinvokeargument name="stIndexField" value="#stFields[field]#" />
					</cfinvoke>

					<cfset stResult[field] = item />
				<cfelseif refind("_(yyyy(mmm(dd)?)?)$", property)>
					<cfif application.fapi.showFarcryDate(arguments.stObject[rereplace(property, "_(yyyy(mmm(dd)?)?)$", "")])>
						<cfset stResult[field] = dateFormat(arguments.stObject[rereplace(property, "_(yyyy(mmm(dd)?)?)$", "")], listlast(property, "_")) />
					<cfelse>
						<cfset stResult[field] = "none" />
					</cfif>
				<cfelseif property eq "status" and not structKeyExists(application.stCOAPI[arguments.stObject.typename].stProps, "status")>
					<cfset stREsult[field] = "approved" />
				<cfelseif structKeyExists(arguments.stObject, property) and structKeyExists(this, "process#rereplace(stFields[field].type, "[^\w]", "", "ALL")#")>
					<cfinvoke component="#this#" method="process#rereplace(stFields[field].type, "[^\w]", "", "ALL")#" returnvariable="item">
						<cfinvokeargument name="stObject" value="#arguments.stObject#" />
						<cfinvokeargument name="property" value="#property#" />
					</cfinvoke>

					<cfif len(item)>
						<cfset stResult[field] = item />
					</cfif>
				</cfif>

		</cfloop>

		<cfreturn stResult />
	</cffunction>

	<cffunction name="processDateTimeOffset" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfif isDate(arguments.stObject[arguments.property])>
			<cfreturn application.fc.lib.azuresearch.getRFC3339Date(arguments.stObject[arguments.property]) />
		<cfelse>
			<cfreturn "" />
		</cfif>
	</cffunction>

	<cffunction name="processBoolean" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfif arguments.stObject[arguments.property]>
			<cfreturn true />
		<cfelse>
			<cfreturn false />
		</cfif>
	</cffunction>

	<cffunction name="processDouble" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var value = arguments.stObject[arguments.property] />

		<cfif len(value)>
			<cfreturn value />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault", ""))>
			<cfreturn application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault") />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default", ""))>
			<cfreturn application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default") />
		</cfif>
	</cffunction>

	<cffunction name="processInt32" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfreturn processInt64(argumentCollection=arguments) />
	</cffunction>

	<cffunction name="processInt64" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var value = arguments.stObject[arguments.property] />

		<cfif len(value)>
			<cfreturn int(value) />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "ftDefault", ""))>
			<cfreturn int(application.fapi.getPropertyMetadata(arguments.stObject.typename, property, "ftDefault")) />
		<cfelseif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default", ""))>
			<cfreturn int(application.fapi.getPropertyMetadata(arguments.stObject.typename, arguments.property, "default")) />
		</cfif>
	</cffunction>

	<cffunction name="processGeographyPoint" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfreturn arguments.stObject[arguments.property] />
	</cffunction>

	<cffunction name="processLiteral" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfreturn application.fc.lib.azuresearch.sanitizeString(arguments.stObject[arguments.property]) />
	</cffunction>

	<cffunction name="processCollectionLiteral" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(value,",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, item.data) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfset aResult = value />
		</cfif>

		<cfreturn aResult />
	</cffunction>

	<cffunction name="processString" access="public" output="false" returntype="string">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var result = "" />

		<cfif len(application.fapi.getPropertyMetadata(arguments.stObject.typename, property, "ftRichtextConfig", ""))>
			<cfset result = rereplace(arguments.stObject[property], "<[^>]+>", " ", "ALL") />
		<cfelse>
			<cfset result = arguments.stObject[property] />
		</cfif>

		<cfreturn application.fc.lib.azuresearch.sanitizeString(result) />
	</cffunction>

	<cffunction name="processCollectionString" access="public" output="false" returntype="array">
		<cfargument name="stObject" type="struct" required="true" />
		<cfargument name="property" type="string" required="true" />

		<cfset var aResult = [] />
		<cfset var value = arguments.stObject[arguments.property] />
		<cfset var item = "" />

		<cfif isSimpleValue(value)>
			<cfset aResult = listToArray(application.fc.lib.azuresearch.sanitizeString(value),",#chr(10)##chr(13)#") />
		<cfelseif arrayLen(value) and isstruct(value[1])>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.azuresearch.sanitizeString(item.data)) />
			</cfloop>
		<cfelseif arrayLen(value)>
			<cfloop array="#value#" index="item">
				<cfset arrayAppend(aResult, application.fc.lib.azuresearch.sanitizeString(item)) />
			</cfloop>
		</cfif>

		<cfreturn aResult />
	</cffunction>

</cfcomponent>