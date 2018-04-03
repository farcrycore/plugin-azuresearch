component {

	public any function init(){
		this.fieldCache = {};
		this.domainEndpoints = {};
		this.invalidchars = createObject("java", "java.util.regex.Pattern").compile( javaCast( "string", "[^\x{0009}\x{000a}\x{000d}\x{0020}-\x{D7FF}\x{E000}-\x{FFFD}]" ) );

		return this;
	}

	public query function getAllContentTypes(string lObjectIDs=""){
		var stArgs = {
			"typename" = "asContentType",
			"lProperties" = "objectid,contentType,label",
			"orderBy" = "contentType"
		}

		if (listLen(arguments.lObjectIds)){
			stArgs["objectid_in"] = arguments.lObjectIds;
		}

		// TODO:  throws error
		// if (bIncludeNonSearchable eq false){
		//	stArgs["objectid_in"] = arguments.lObjectIds;
		//}

		return application.fapi.getContentObjects(argumentCollection=stArgs);
	}

	public query function getFieldTypes(){
		var q = querynew("code,label");

		queryAddRow(q);
		querySetCell(q,"code","Boolean");
		querySetCell(q,"label","Boolean");

		queryAddRow(q);
		querySetCell(q,"code","DateTimeOffset");
		querySetCell(q,"label","Date");

		queryAddRow(q);
		querySetCell(q,"code","Double");
		querySetCell(q,"label","Double");

		queryAddRow(q);
		querySetCell(q,"code","GeographyPoint");
		querySetCell(q,"label","Lat, Long pair");

		queryAddRow(q);
		querySetCell(q,"code","Int32");
		querySetCell(q,"label","Integer (32b)");

		queryAddRow(q);
		querySetCell(q,"code","Int64");
		querySetCell(q,"label","Integer (64b)");

		queryAddRow(q);
		querySetCell(q,"code","Literal");
		querySetCell(q,"label","Literal");

		queryAddRow(q);
		querySetCell(q,"code","CollectionLiteral");
		querySetCell(q,"label","Literal Array");

		queryAddRow(q);
		querySetCell(q,"code","String");
		querySetCell(q,"label","String");

		queryAddRow(q);
		querySetCell(q,"code","CollectionString");
		querySetCell(q,"label","String Array");

		return q;
	}

	public string function getDefaultFieldType(required struct stMeta){
		switch (stMeta.type){
			case "string":
				switch (stMeta.ftType){
					case "list":
						if (stMeta.ftSelectMultiple)
							return "Literal";
						else
							return "Literal";
					case "category":
						return "CollectionLiteral";
				}

			case "varchar": case "longchar":
				return "String";

			case "numeric":
				return "Double";

			case "integer":
				return "Int64";

			case "uuid":
				return "Literal";

			case "array":
				return "CollectionLiteral";

			case "datetime": case "date":
				return "DateTimeOffset";

			case "boolean":
				return "Boolean";

			default:
				return "String";
		}
	}

	public boolean function isEnabled(){
		var serviceName = application.fapi.getConfig("azuresearch","serviceName","");
		var accessKey = application.fapi.getConfig("azuresearch","accessKey","");
		var index = application.fapi.getConfig("azuresearch","index","");

		return len(serviceName) AND len(accessKey) AND len(index);
	}

	/* CloudSearch API Wrappers */
	public any function makeRequest(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string accessKey=application.fapi.getConfig("azuresearch","accessKey",""),
		required string resource,
		string method="",
		struct stData={},
		struct stQuery={},
		struct stHeaders={},
		numeric timeout=30
	) {
		var resourceURL = arguments.resource;
		var item = "";
		var cfhttp = {};

		arguments.stQuery["api-version"] = "2016-09-01";
		arguments.stHeaders["api-key"] = arguments.accessKey;

		for (item in arguments.stQuery) {
			if (find("?", resourceURL)) {
				resourceURL = resourceURL & "&";
			}
			else {
				resourceURL = resourceURL & "?";
			}

			resourceURL = resourceURL & URLEncodedFormat(item) & "=" & URLEncodedFormat(arguments.stQuery[item]);
		}

		if (arguments.method eq "") {
			if (structisempty(arguments.stData)) {
				arguments.method = "GET";
			}
			else {
				arguments.method = "POST";
			}
		}

		cfhttp(method=arguments.method, url="https://#arguments.serviceName#.search.windows.net#resourceURL#", timeout=arguments.timeout) {
			for (item in arguments.stHeaders) {
				cfhttpparam(type="header", name=item, value=arguments.stHeaders[item]);
			}

			if (not structisempty(arguments.stData)) {
				cfhttpparam(type="header", name="Content-Type", value="application/json");
				cfhttpparam(type="body", value="#serializeJSON(arguments.stData)#");
			}
		}

		if (not refindnocase("^20. ",cfhttp.statuscode)) {
			throw(message="Error accessing Microsoft Azure Search: #cfhttp.statuscode#", detail="#serializeJSON({
				'resource' = arguments.resource,
				'method' = arguments.method,
				'query_string' = arguments.stQuery,
				'body' = arguments.stData,
				'resourceURL' = resourceURL,
				'response' = isjson(cfhttp.filecontent.toString()) ? deserializeJSON(cfhttp.filecontent.toString()) : cfhttp.filecontent.toString()
			})#");
		}

		var result = cfhttp.filecontent.toString();

		if (len(result)) {
			result = deserializeJSON(result);
		}

		return result;
	}

	public struct function createDatasource(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name,
		string description="",
		string connectionString ref="https://docs.microsoft.com/en-us/azure/storage/common/storage-configure-connection-string",
		string container,
		string location
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/create-data-source" {
		if (structKeyExists(arguments, "location")) {
			var location = application.fc.lib.cdn.getLocation(arguments.location);
			arguments.container = location.container;
			arguments.connectionString = "DefaultEndpointsProtocol=https;AccountName=" & location.account & ";AccountKey=" & location.storageKey;
		}

		var stData = {
			"name"=arguments.name,
			"description"=arguments.description,
			"type"="azureblob",
			"credentials"={ "connectionString"=arguments.connectionString },
			"container"={ "name"=arguments.container }
		};

		return makeRequest(serviceName=arguments.serviceName, resource="/datasources", stData=stData);
	}

	public query function getDatasources(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=""
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/list-data-sources" {
		var data = makeRequest(serviceName=arguments.serviceName, resource="/datasources");
		var qResult = queryNew("name,container","varchar,varchar");
		var item = {};

		for (item in data.value) {
			if (item.type eq "azureblob" and (arguments.name eq "" or arguments.name eq item.name)) {
				queryAddRow(qResult);
				querySetCell(qResult, "name", item.name);
				querySetCell(qResult, "container", item.container.name);
			}
		}

		return qResult;
	}

	public void function deleteDatasource(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/delete-data-source" {

		makeRequest(serviceName=arguments.serviceName, method="DELETE", resource="/datasources/#arguments.name#");
	}

	public struct function createIndexer(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name,
		string description="",
		required string dataSourceName,
		string targetIndexName=application.fapi.getConfig("azuresearch", "index"),
		string schedule="PT5M"
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/create-indexer" {
		var stData = {
			"name"=arguments.name,
			"description"=arguments.description,
			"dataSourceName"=arguments.dataSourceName,
			"targetIndexName"=arguments.targetIndexName,
			"parameters"={
				"configuration"={
					"failOnUnsupportedContentType"=false,
					"failOnUnprocessableDocument"=false
				}
			},
			"fieldMappings"=[{
				"sourceFieldName"="objectid",
				"targetFieldName"="objectid_literal"
			},{
				"sourceFieldName"="content",
				"targetFieldName"="filecontent_string"
			}],
			"schedule"={
				"interval"=arguments.schedule
			},
			"disabled"=false
		};

		return makeRequest(serviceName=arguments.serviceName, resource="/indexers", stData=stData );
	}

	public void function updateIndexer(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name,
		string description="",
		required string dataSourceName,
		string targetIndexName=application.fapi.getConfig("azuresearch", "index"),
		string schedule="PT5M"
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/update-indexer" {
		var stData = {
			"name"=arguments.name,
			"description"=arguments.description,
			"dataSourceName"=arguments.dataSourceName,
			"targetIndexName"=arguments.targetIndexName,
			"parameters"={
				"configuration"={
					"failOnUnsupportedContentType"=false,
					"failOnUnprocessableDocument"=false
				}
			},
			"fieldMappings"=[{
				"sourceFieldName"="objectid",
				"targetFieldName"="objectid_literal"
			},{
				"sourceFieldName"="content",
				"targetFieldName"="filecontent_string"
			}],
			"schedule"={
				"interval"=arguments.schedule
			},
			"disabled"=false
		};

		return makeRequest(serviceName=arguments.serviceName, method="PUT", resource="/indexers/#arguments.name#", stData=stData);
	}

	public void function deleteIndexer(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/delete-indexer" {

		makeRequest(serviceName=arguments.serviceName, method="DELETE", resource="/indexers/#arguments.name#");
	}

	public void function runIndexer(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/run-indexer" {

		makeRequest(serviceName=arguments.serviceName, method="POST", resource="/indexers/#arguments.name#/run");
	}

	public struct function getIndexerStatus(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		required string name
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/get-indexer-status" {
		var stResult = makeRequest(serviceName=arguments.serviceName, method="GET", resource="/indexers/#arguments.name#/status");
		var qRuns = queryNew("status,errorMessage,startTime,endTime,itemsProcessed","varchar,varchar,date,date,numeric");
		var item = {};

		for (item in stResult.executionHistory) {
			queryAddRow(qRuns);
			querySetCell(qRuns, "status", item.status);
			if (structKeyExists(item, "errorMessage")) {
				querySetCell(qRuns, "errorMessage", item.errorMessage);
			}
			querySetCell(qRuns, "startTime", RFC3339ToDate(item.startTime));
			querySetCell(qRuns, "endTime", RFC3339ToDate(item.endTime));
			querySetCell(qRuns, "itemsProcessed", item.itemsProcessed);
		}

		return {
			"name" = stResult.name,
			"status" = stResult.status,
			"runs" = qRuns
		};
	}

	public query function getIndexers(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string targetIndexName=application.fapi.getConfig("azuresearch", "index"),
		string name=""
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/list-indexers" {
		var data = makeRequest(serviceName=arguments.serviceName, resource="/indexers");
		var qResult = queryNew("name,description,dataSourceName,targetIndexName","varchar,varchar,varchar,varchar");
		var item = {};

		for (item in data.value) {
			if ((arguments.targetIndexName eq "" or arguments.targetIndexName eq item.targetIndexName) and (arguments.name eq "" or arguments.name eq item.name)) {
				queryAddRow(qResult);
				querySetCell(qResult, "name", item.name);
				querySetCell(qResult, "description", item.description);
				querySetCell(qResult, "dataSourceName", item.dataSourceName);
				querySetCell(qResult, "targetIndexName", item.targetIndexName);
			}
		}

		return qResult;
	}

	public query function getExpectedIndexers(string name="") {
		var qLocations = application.fc.lib.cdn.getLocations();
		var i = 0;
		var location = {};

		queryAddColumn(qLocations, "container");
		queryAddColumn(qLocations, "description");
		queryAddColumn(qLocations, "dataSourceName");
		queryAddColumn(qLocations, "targetIndexName");

		for (i=qLocations.recordcount; i>=1; i--) {
			if (qLocations.type[i] eq "azure") {
				location = application.fc.lib.cdn.getLocation(qLocations.name[i]);
				if (structKeyExists(location, "indexable") and location.indexable and (arguments.name eq "" or arguments.name eq location.name)) {
					querySetCell(qLocations, "container", location.container, i);
					querySetCell(qLocations, "description", location.container & " indexer", i);
					querySetCell(qLocations, "dataSourceName", location.container, i);
					querySetCell(qLocations, "targetIndexName", application.fapi.getConfig("azuresearch", "index"), i);
				}
				else {
					queryDeleteRow(qLocations, i);
				}
			}
			else {
				queryDeleteRow(qLocations, i);
			}
		}

		queryDeleteColumn(qLocations, "type");

		return qLocations;
	}

	public query function diffIndexers(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string targetIndexName=application.fapi.getConfig("azuresearch", "index"),
		query existingIndexers,
		query expectedIndexers
	) {
		var stExpected = {};
		var row = "";
		var i = "";
		var changes = "";

		if (not structKeyExists(arguments, "existingIndexers")) {
			arguments.existingIndexers = getIndexers(serviceName=arguments.serviceName, targetIndexName=arguments.targetIndexName);
		}
		if (not structKeyExists(arguments, "expectedIndexers")) {
			arguments.expectedIndexers = getExpectedIndexers();
		}

		for (row in arguments.expectedIndexers) {
			stExpected[row.name] = row;
		}

		queryAddColumn(arguments.existingIndexers, "container");
		queryAddColumn(arguments.existingIndexers, "action");
		for (i=1; i<=arguments.existingIndexers.recordcount; i++) {
			if (not structKeyExists(stExpected, arguments.existingIndexers.name[i])) {
				querySetCell(arguments.existingIndexers, "action", "delete");
				continue;
			}

			row = stExpected[arguments.existingIndexers.name[i]];
			querySetCell(arguments.existingIndexers, "container", arguments.existingIndexers.name[i], i);
			querySetCell(arguments.existingIndexers, "name", row.name, i);
			if (arguments.existingIndexers.description[i] neq row.description) {
				changes = listAppend(changes, "description(" & arguments.existingIndexers.description[i] & "=>" & row.description & ")");
			}
			if (arguments.existingIndexers.dataSourceName[i] neq row.dataSourceName) {
				changes = listAppend(changes, "dataSourceName(" & arguments.existingIndexers.dataSourceName[i] & "=>" & row.dataSourceName & ")");
			}
			if (arguments.existingIndexers.targetIndexName[i] neq row.targetIndexName) {
				changes = listAppend(changes, "targetIndexName(" & arguments.existingIndexers.targetIndexName[i] & "=>" & row.targetIndexName & ")");
			}
			if (len(changes)) {
				querySetCell(arguments.existingIndexers, "action", "update:" & changes);
			}

			structDelete(stExpected, row.name);
		}

		for (i in stExpected) {
			queryAddRow(arguments.existingIndexers);
			querySetCell(arguments.existingIndexers, "name", stExpected[i].name);
			querySetCell(arguments.existingIndexers, "container", stExpected[i].container);
			querySetCell(arguments.existingIndexers, "description", stExpected[i].description);
			querySetCell(arguments.existingIndexers, "dataSourceName", stExpected[i].dataSourceName);
			querySetCell(arguments.existingIndexers, "targetIndexName", stExpected[i].targetIndexName);
			querySetCell(arguments.existingIndexers, "action", "add");
		}

		return arguments.existingIndexers;
	}

	public query function getIndexes(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/list-indexes" {
		var data = makeRequest(serviceName=arguments.serviceName, resource="/indexes", stQuery={ "$select"="name" });
		var item = {};
		var qResult = queryNew("name")

		for (item in data.value){
			queryAddRow(qResult);
			querySetCell(qResult, "name", item.name);
		}

		return qResult;
	}

	public struct function getIndex(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index")
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/get-index" {
		try {
			return makeRequest(serviceName=arguments.serviceName, resource="/indexes/#arguments.name#");
		}
		catch (err) {
			if (err.message eq "Error accessing Microsoft Azure Search: 404 Not Found") {
				return {
					"name": arguments.name,
					"fields": []
				};
			}

			rethrow;
		}
	}

	public query function getIndexFields(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index")
	) {
		var data = getIndex(argumentCollection=arguments);
		var qResult = querynew("field,type,return,search,facet,sort,analyzer","varchar,varchar,bit,bit,bit,bit,varchar");
		var field = {};

		for (field in data.fields){
			queryAddRow(qResult);
			insertIndexFieldOptions(qResult, qResult.recordcount, field);
		}

		return qResult;
	}

	private array function localToAzureFields(required query qFields) {
		var row = {};
		var field = {};
		var aFields = [];
		var lFields = "";

		for (row in arguments.qFields) {
			if (not listFindNoCase(lFields, row.field)) {
				field = {
					"name" = row.field,
					"sortable" = row.sort eq 1,
					"facetable" = row.facet eq 1,
					"retrievable" = row["return"] eq 1,
					"key" = row.field eq "objectid_literal"
				};

				switch (row.type) {
					case "Boolean":
						field["type"] = "Edm.Boolean";
						field["filterable"] = true;
						break;
					case "DateTimeOffset":
						field["type"] = "Edm.DateTimeOffset";
						field["filterable"] = true;
						break;
					case "Double":
						field["type"] = "Edm.Double";
						field["filterable"] = true;
						break;
					case "GeographyPoint":
						field["type"] = "Edm.GeographyPoint";
						field["filterable"] = true;
						break;
					case "Int32":
						field["type"] = "Edm.Int32";
						field["filterable"] = true;
						break;
					case "Int64":
						field["type"] = "Edm.Int64";
						field["filterable"] = true;
						break;
					case "Literal":
						field["type"] = "Edm.String";
						field["filterable"] = true;
						field["analyzer"] = "keyword";
						break;
					case "CollectionLiteral":
						field["type"] = "Collection(Edm.String)";
						field["filterable"] = true;
						field["analyzer"] = "keyword";
						break;
					case "String":
						field["type"] = "Edm.String";
						field["searchable"] = true;
						field["analyzer"] = "standard";
						break;
					case "CollectionString":
						field["type"] = "Collection(Edm.String)";
						field["searchable"] = true;
						field["analyzer"] = "standard";
						break;
				}

				arrayAppend(aFields, field);
				lFields = listAppend(lFields, row.field);
			}
		}

		return aFields;
	}

	public struct function createIndex(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index")
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/Create-Index" {
		var qFields = application.fapi.getContentType("asContentType").getIndexFields();
		var data = {
			"name" = arguments.name,
			"fields" = localToAzureFields(qFields),
			"suggesters": [],
			"scoringProfiles": []
		};

		return makeRequest(serviceName=arguments.serviceName, resource="/indexes", stData=data);
	}

	public void function updateIndex(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index")
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/update-index" {
		var qFields = application.fapi.getContentType("asContentType").getIndexFields();
		var data = {
			"name" = arguments.name,
			"fields" = localToAzureFields(qFields),
			"suggesters": [],
			"scoringProfiles": []
		};

		makeRequest(serviceName=arguments.serviceName, method="PUT", resource="/indexes/#arguments.name#", stData=data);
	}

	public struct function deleteIndex(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index")
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/delete-index" {

		return makeRequest(serviceName=arguments.serviceName, method="DELETE", resource="/indexes/#arguments.name#");
	}

	public struct function uploadDocuments(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string name=application.fapi.getConfig("azuresearch", "index"),
		required array documents
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/addupdate-or-delete-documents" {
		var data = {
			"value": arguments.documents
		};

		return makeRequest(serviceName=arguments.serviceName, resource="/indexes/#arguments.name#/docs/index", stData=data);
	}

	public struct function lookupDocument(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string index=application.fapi.getConfig("azuresearch", "index"),
		required string key
	) key="https://docs.microsoft.com/en-us/rest/api/searchservice/lookup-document" {

		return makeRequest(
			serviceName=arguments.serviceName,
			resource="/indexes/#arguments.index#/docs/#arguments.key#"
		);
	}

	public struct function search(
		string serviceName=application.fapi.getConfig("azuresearch","serviceName",""),
		string index=application.fapi.getConfig("azuresearch", "index"),
		string typename,
		string rawQuery,
		string queryParser="simple",
		string rawFilter,
		string rawFacets,
		array conditions,
		array filters,
		struct facets={},
		numeric maxrows=10,
		numeric page=1,
		string sort="search.score() desc"
	) ref="https://docs.microsoft.com/en-us/rest/api/searchservice/search-documents" {
		// collect index field information
		if (structKeyExists(arguments,"typename") and len(arguments.typename)){
			// filter by content type
			if (listlen(arguments.typename)){
				for (key in listtoarray(arguments.typename)){
					structAppend(stIndexFields, getTypeIndexFields(key));
				}
			}
			else {
				stIndexFields = getTypeIndexFields(arguments.typename);
			}
		}
		else {
			stIndexFields = getTypeIndexFields();
		}

		// create filter
		if (not structKeyExists(arguments,"rawFilter")){
			if (not structKeyExists(arguments,"filters")){
				arguments.filters = [];
			}

			if (structKeyExists(arguments,"typename") and len(arguments.typename)){
				// filter by content type
				if (listlen(arguments.typename)){
					arrayPrepend(arguments.filters, { "or"=[] });

					for (key in listtoarray(arguments.typename)){
						arrayAppend(arguments.filters[1]["or"],{ "property"="typename", "term"=key });
					}
				}
				else {
					arrayPrepend(arguments.filters, { "property"="typename", "term"=arguments.typename });
				}
			}

			if (arraylen(arguments.filters)){
				arguments.rawFilter = getSearchQueryFromArray(stIndexFields=stIndexFields, conditions=arguments.filters, bBoost=false).query;

				if (arraylen(arguments.filters) gt 1){
					arguments.rawFilter = "(and " & chr(10) & arguments.rawFilter & chr(10) & ")";
				}
			}
			else {
				arguments.rawFilter = "";
			}
		}

		// create facet config
		if (not structKeyExists(arguments,"rawFacets")){
			if (not structKeyExists(arguments,"facets")){
				arguments.facets = {};
			}

			st = {};
			for (key in arguments.facets) {
				for (keyS in stIndexFields) {
					if (stIndexFields[keyS].property eq key) {
						arguments.rawFacets = listAppend(arguments.rawFacets, "#stIndexFields[keyS].field#,#arguments.facets[key]#", ";");
					}
				}
			}
		}

		var stQuery={
			"search"=arguments.rawQuery,
			"skip"=arguments.maxrows * (arguments.page - 1),
			"top"=arguments.maxrows,
			"select"="objectid_literal,typename_literal",
			"count"=true
		}
		if (structKeyExists(arguments, "rawFacets") and len(arguments.rawFacets)) {
			stQuery["facets"] = listToArray(arguments.rawFacets, ";");
		}
		if (structKeyExists(arguments, "rawFilter") and len(arguments.rawFilter)) {
			stQuery["filter"] = arguments.rawFilter;
		}

		var result = makeRequest(
			serviceName=arguments.serviceName,
			resource="/indexes/#arguments.index#/docs/search",
			stData=stQuery
		);

		result["items"] = convertResultsToQuery(result.value);
		if (structKeyExists(result, "@search.facets")) {
			result["facetQueries"] = convertFacetsToQueries(result["@search.facets"]);
		}
		result["query"] = stQuery;

		return result;
	}


	private query function convertResultsToQuery(required array input) {
		var qResult = queryNew("objectid,typename,score", "varchar,varchar,numeric");
		var item = {};

		for (item in arguments.input) {
			queryAddRow(qResult);
			querySetCell(qResult, "objectid", item.objectid_literal);
			querySetCell(qResult, "typename", item.typename_literal);
			querySetCell(qResult, "score", item["@search.score"]);
		}

		return qResult;
	}

	private struct function convertFacetsToQueries(required struct facets) {
		var qResult = {};
		var field = {};
		var stIndexFields = getTypeIndexFields();
		var result = {};
		var stResult = {};

		for (field in arguments.facets) {
			if (structKeyExists(stIndexFields, field)) {
				qResult = queryNew("value,count", "varchar,numeric");

				for (result in arguments.facets[field]) {
					queryAddRow(qResult);
					querySetCell(qResult, "value", result.value);
					querySetCell(qResult, "count", result.count);
				}

				stResult[stIndexFields[field].property] = qResult;
			}
		}

		return stResult;
	}

	public string function sanitizeString(required string input) {
		var matcher = this.invalidchars.matcher( javaCast( "string", arguments.input ) );

		return matcher.replaceAll( javaCast( "string", "" ) );
	}

	/* CloudSearch Utility functions */
	private query function createIndexQuery(){
		return querynew("field,type,return,search,facet,sort,analyzer,state","varchar,varchar,varchar,bit,bit,bit,bit,bit,varchar,varchar");
	}

	private any function insertIndexFieldOptions(required query q, required numeric row, required struct field){
		querySetCell(arguments.q, "field", arguments.field.name, arguments.row);

		switch (arguments.field.type) {
			case "Edm.String":
				if (field.analyzer eq "keyword")
					querySetCell(arguments.q, "type", "Literal", arguments.row);
				else if
					querySetCell(arguments.q, "type", "String", arguments.row);
				break;
			case "Collection(Edm.String)":
				if (field.analyzer eq "keyword")
					querySetCell(arguments.q, "type", "CollectionLiteral", arguments.row);
				else if
					querySetCell(arguments.q, "type", "CollectionString", arguments.row);
				break;
			case "Edm.Boolean":
				querySetCell(arguments.q, "type", "Boolean", arguments.row);
				break;
			case "Edm.Int32":
				querySetCell(arguments.q, "type", "Int32", arguments.row);
				break;
			case "Edm.Int64":
				querySetCell(arguments.q, "type", "Int64", arguments.row);
				break;
			case "Edm.Double":
				querySetCell(arguments.q, "type", "Double", arguments.row);
				break;
			case "Edm.DateTimeOffset":
				querySetCell(arguments.q, "type", "DateTimeOffset", arguments.row);
				break;
			case "Edm.GeographyPoint":
				querySetCell(arguments.q, "type", "GeographyPoint", arguments.row);
				break;
		}
		querySetCell(arguments.q, "return", arguments.field.retrievable, arguments.row);
		querySetCell(arguments.q, "search", 1, arguments.row);
		querySetCell(arguments.q, "facet", arguments.field.facetable, arguments.row);
		querySetCell(arguments.q, "sort", arguments.field.sortable, arguments.row);

		if (structKeyExists(arguments.field, "analyzer")) {
			querySetCell(arguments.q, "analyzer", arguments.field.analyzer, arguments.row);
		}
	}

	public string function getRFC3339Date(required date d){
		var asUTC = dateConvert("local2utc", arguments.d);

		return dateformat(asUTC,"yyyy-mm-dd") & "T" & timeformat(asUTC,"HH:mm:ss") & "Z";
	}

	public date function RFC3339ToDate(required any input, boolean includeTime=true) {
		var sdf = "";
		var pos = "";
		var rdate = "";

		if (arguments.includeTime) {
			if (not reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1,3}Z$", arguments.input)) {
				throw(message="Date/time must be in the form yyyy-MM-ddTHH:mm:ss.SSSZ: #arguments.input#");
			}
		}
		else {
			if (not reFind("^\d{4}-\d{2}-\d{2}$", arguments.input)) {
				throw(message="Date must be in the form yyyy-MM-dd: #arguments.input#");
			}
		}

		if (arguments.includeTime) {
			if (reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{1}Z$", arguments.input)) {
				sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.S'Z'");
			}
			if (reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{2}Z$", arguments.input)) {
				sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SS'Z'");
			}
			if (reFind("^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$", arguments.input)) {
				sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'");
			}
		}
		else {
			sdf = CreateObject("java", "java.text.SimpleDateFormat").init("yyyy-MM-dd");
		}
		pos = CreateObject("java", "java.text.ParsePosition").init(0);

		rdate = sdf.parse(arguments.input, pos);

		return application.fc.LIB.TIMEZONE.castFromUTC(rdate, application.fc.serverTimezone);
	}

	public string function getSearchQueryFromArray(required struct stIndexFields, required array conditions, boolean bBoost=true, string logicalJoin="and"){
		var item = {};
		var arrOut = [];

		for (item in arguments.conditions){
			if (isSimpleValue(item)){
				arrayAppend(arrOut, item);
			}
			else if (structKeyExists(item,"property")){
				item["stIndexFields"] = arguments.stIndexFields;
				arrayAppend(arrOut, getFieldQuery(argumentCollection=item, bBoost=arguments.bBoost));
				structDelete(item,"stIndexFields");
			}
			else if (structKeyExists(item,"text")) {
				arrayAppend(arrOut,getTextSearchQuery(stIndexFields=arguments.stIndexFields, text=item.text));
			}
			else if (structKeyExists(item,"and")) {
				if (arraylen(item["and"]) gt 1){
					arrayAppend(arrOut, getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["and"]));
				}
				else {
					arrayAppend(arrOut, getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["and"]));
				}
			}
			else if (structKeyExists(item,"or")) {
				if (arraylen(item["or"]) gt 1){
					arrayAppend(arrOut, getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["or"], logicalJoin="or"));
				}
				else {
					arrayAppend(arrOut, getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["or"], logicalJoin="or"));
				}
			}
			else if (structKeyExists(item,"not")) {
				arrayAppend(arrOut,"(not " & getSearchQueryFromArray(stIndexFields=arguments.stIndexFields, conditions=item["not"]) & ")");
			}
		}

		return "(" & arrayToList(arrOut, " " & logicalJoin & " ") & ")";
	}

	private string function getTextValue(required string text){
		return "'" & replacelist(trim(rereplace(arguments.text,"\s+"," ","ALL")),"', ","\',' '") & "'";
	}

	private string function getRangeValue(required struct stIndexField){
		var field = arguments.stIndexField.field;
		var value = "";
		var clauses = [];
		var op = "";

		for (op in ["gt,gte,lt,lte"]) {
			if (structKeyExists(arguments, op)) {
				value = arguments[op];

				switch (arguments.stIndexField.type){
					case "Int32": case "Int64": case "Double":
						arrayAppend(clauses, "#field# #op# #value#");
						break;
					case "String": case "CollectionString": case "Literal": case "CollectionLiteral":
						arrayAppend(clauses, "#field# #op# '#replace(value,"'","\'")#'");
						break;
					case "DateTimeOffset":
						arrayAppend(clauses, "#field# #op# '#getRFC3339Date(value)#'");
						break;
				}
			}
		}

		if (arrayLen(clauses) eq 1) {
			return clauses[1];
		}
		else {
			return "(" & arrayToList(clauses, " and ") & ")";
		}

		return str;
	}

	private string function getTextSearchQuery(required struct stIndexFields, required string text){
		var aSubQuery = [];
		var key = "";
		var textStr = getTextValue(arguments.text);
		var boost = "";

		for (key in arguments.stIndexFields){
			if (listfindnocase("String,CollectionString",arguments.stIndexFields[key].type)) {
				arrayAppend(aSubQuery, "search.ismatchscoring('#textStr#', '#arguments.stIndexFields[key].field#')");
			}
		}

		return "(" & arraytolist(aSubQuery, " or ") & ")";
	}

	private string function getFieldQuery(required struct stIndexFields, required string property){
		var key = "";
		var aSubQuery = [];
		var str = "";
		var value = "";
		var boost = "";

		if (structKeyExists(arguments,"text")){
			value = getTextValue(arguments.text);
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property and listfindnocase("String,CollectionString",arguments.stIndexFields[key].type)) {
					arrayAppend(aSubQuery, "search.ismatchscoring('#value#', '#arguments.stIndexFields[key].field#')");
				}
			}
		}
		else if (structKeyExists(arguments,"term")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					switch (arguments.stIndexFields[key].type){
						case "Boolean":
							value = arguments.term ? "true" : "false";
							break;
						case "Int32": case "Int64": case "Double":
							value = arguments.term;
							break;
						case "String": case "CollectionString": case "Literal": case "CollectionLiteral":
							value = "'#replace(arguments.term,"'","\'")#'";
							break;
						case "DateTimeOffset":
							value = "'#getRFC3339Date(arguments.term)#'";
							break;
					}

					arrayAppend(aSubQuery, "#arguments.stIndexFields[key].field# eq #value#");
				}
			}
		}
		else if (structKeyExists(arguments,"range")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					arrayAppend(aSubQuery, getRangeValue(stIndexField=arguments.stIndexFields[key],argumentCollection=arguments.range));
				}
			}
		}
		else if (structKeyExists(arguments,"dateafter")){
			for (key in arguments.stIndexFields){
				if (arguments.stIndexFields[key].property eq arguments.property) {
					arrayAppend(aSubQuery, "#arguments.stIndexFields[key].field# gt #getRFC3339Date(arguments.dateafter)#");
				}
			}

		}

		if (arrayLen(aSubQuery) gt 1){
			return "(" & arrayToList(aSubQuery, " or ") & ")";
		}
		else if (arraylen(aSubQuery)) {
			return aSubQuery[1];
		}
		else {
			throw(message="No query generated from arguments", detail=serializeJSON(arguments));
		}
	}


	public query function diffIndexFields(query qOldFields, query qNewFields, string fields=""){
		var stOld = {};
		var stNew = {};
		var stField = {};
		var field = "";
		var qResult = querynew("field,type,return,search,facet,sort,analyzer,action","varchar,varchar,bit,bit,bit,bit,varchar,varchar");
		var changes = "";
		var i = "";

		/* Default to Azure config for old, and FarCry config for new */
		if (not structKeyExists(arguments,"qOldFields")){
			arguments.qOldFields = getIndexFields();
		}
		if (not structKeyExists(arguments,"qNewFields")){
			arguments.qNewFields = application.fapi.getContentType("asContentType").getIndexFields();
		}

		/* Convert queries to structs for easier comparison */
		for (stField in arguments.qOldFields){
			stOld[stField.field] = duplicate(stField);
		}
		for (stField in arguments.qNewFields){
			stNew[stField.field] = duplicate(stField);
		}

		for (field in stOld){
			if (not structKeyExists(stNew,field) and (arguments.fields == "" or listfindnocase(arguments.fields,field))){
				queryAddRow(qResult);
				querySetCell(qResult,"action","delete");
				querySetCell(qResult,"field",field);
				querySetCell(qResult,"type",stOld[field].type);
				querySetCell(qResult,"return",stOld[field].return);
				querySetCell(qResult,"search",stOld[field].search);
				querySetCell(qResult,"facet",stOld[field].facet);
				querySetCell(qResult,"sort",stOld[field].sort);
				querySetCell(qResult,"analyzer",stOld[field].analyzer);
			}
		}

		for (field in stNew){
			if (not structKeyExists(stOld,field) and (arguments.fields == "" or listfindnocase(arguments.fields,field))){
				/* Item was added */
				queryAddRow(qResult);
				querySetCell(qResult,"field",field);
				querySetCell(qResult,"type",stNew[field].type);
				querySetCell(qResult,"return",stNew[field].return);
				querySetCell(qResult,"search",stNew[field].search);
				querySetCell(qResult,"facet",stNew[field].facet);
				querySetCell(qResult,"sort",stNew[field].sort);
				querySetCell(qResult,"analyzer",stNew[field].analyzer);
				querySetCell(qResult,"action","add");
			}
			else if (structKeyExists(stOld,field) and (arguments.fields == "" or listfindnocase(arguments.fields,field))) {
				changes = "";

				for (i in ["return","type","search","facet","sort","analyzer"]) {
					if (i eq "type" and stOld[field][i] eq "String" and stNew[field][i] eq "Literal") {
						// ignore
					}
					else if  (i eq "type" and stOld[field][i] eq "CollectionString" and stNew[field][i] eq "CollectionLiteral") {
						// ignore
					}
					else if (stOld[field][i] != stNew[field][i]) {
						changes = listAppend(changes, i & "(" & stOld[field][i] & "=>" & stNew[field][i] & ")");
					}
				}

				if (len(changes)) {
					/* Item was changed */
					queryAddRow(qResult);
					querySetCell(qResult,"field",field);
					querySetCell(qResult,"type",stNew[field].type);
					querySetCell(qResult,"return",stNew[field].return);
					querySetCell(qResult,"search",stNew[field].search);
					querySetCell(qResult,"facet",stNew[field].facet);
					querySetCell(qResult,"sort",stNew[field].sort);
					querySetCell(qResult,"analyzer",stNew[field].analyzer);
					querySetCell(qResult,"action","update:#changes#");
				}
			}
		}

		return qResult;
	}

	public struct function getTypeIndexFields(string typename="all", boolean bUseCache=true){
		if (not structKeyExists(this.fieldCache,arguments.typename) or not arguments.bUseCache){
			updateTypeIndexFieldCache(arguments.typename);
		}

		return this.fieldCache[arguments.typename];
	}

	public void function updateTypeIndexFieldCache(string typename="all"){
		var qIndexFields = "";
		var stContentType = {};
		var stField = {};

		this.fieldCache[arguments.typename] = {};

		if (arguments.typename eq "all"){
			qIndexFields = application.fapi.getContentType(typename="asContentType").getIndexFields();
		}
		else {
			qIndexFields = application.fapi.getContentType(typename="asContentType").getIndexFields(arguments.typename);
		}

		for (stField in qIndexFields){
			this.fieldCache[arguments.typename][qIndexFields.field] = {
				"field" = qIndexFields.field,
				"property" = qIndexFields.property,
				"type" = stField.type,
				"facet" = stField.facet
			}
		}
	}

}