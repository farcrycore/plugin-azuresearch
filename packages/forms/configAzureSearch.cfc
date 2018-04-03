<cfcomponent extends="farcry.core.packages.forms.forms" key="azuresearch" displayname="Azure Search" hint="Microsoft Azure Search settings">

	<cfproperty name="servicename" type="string" required="false"
		ftSeq="1" ftWizardStep="" ftFieldset="Azure" ftLabel="Service Name">

	<cfproperty name="index" type="string" required="false"
		ftSeq="2" ftWizardStep="" ftFieldset="Azure" ftLabel="Index">

	<cfproperty name="accessKey" type="string" required="false"
		ftSeq="3" ftWizardStep="" ftFieldset="Azure" ftLabel="Access Key">


	<!--- TODO: convert to whatever is useful for Azure search --->
	<cffunction name="getSubsets" access="public" output="false" returntype="query">
		<cfset var qResult = querynew("value,label,order","varchar,varchar,integer") />
		<cfset var qContentTypes = application.fc.lib.cloudsearch.getAllContentTypes()>
		<cfset var k = "" />
		
		<cfset queryaddrow(qResult) />
		<cfset querysetcell(qResult,"value","") />
		<cfset querysetcell(qResult,"label","All") />
		<cfset querysetcell(qResult,"order",0) />
		
		
		
		<cfloop query="#qContentTypes#">
			<cfif application.stCOAPI[qContentTypes.contentType].class eq "type" and structkeyexists(application.stCOAPI[qContentTypes.contentType],"displayname") and (not structkeyexists(application.stCOAPI[qContentTypes.contentType],"bSystem") or not application.stCOAPI[qContentTypes.contentType].bSystem)>
				<cfset queryaddrow(qResult) />
				<cfset querysetcell(qResult,"value",qContentTypes.contentType) />
				<cfset querysetcell(qResult,"label","#application.stCOAPI[qContentTypes.contentType].displayname# (#qContentTypes.contentType#)") />
				<cfset querysetcell(qResult,"order",1) />
			</cfif>
		</cfloop>
		
		<cfquery dbtype="query" name="qResult">select * from qResult order by [order],[label]</cfquery>
		
		
		<cfreturn qResult />
	</cffunction>
</cfcomponent>