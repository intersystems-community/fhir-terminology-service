Class iscru.fhir.fts.FTSInteractions Extends HS.FHIRServer.Storage.Json.Interactions
{

/// Custom Operations class
Parameter OperationHandlerClass As %String = "iscru.fhir.fts.FTSOperations";

Property lastSearchResult As HS.FHIRServer.Util.SearchResult [ Private, Transient ];

Property currentFHIRService As HS.FHIRServer.API.Service [ Private, Transient ];

/// @API Notification that a request in about to be dispatched.  
/// @Input pFHIRService  The instance of HS.FHIRServer.Service that invoked this method
/// @Input pFHIRRequest  The request about to be processed
/// @Input pTimeout      The maximum number of sessions between requests that session data remains valid
Method OnBeforeRequest(pFHIRService As HS.FHIRServer.API.Service, pFHIRRequest As HS.FHIRServer.API.Data.Request, pTimeout As %Integer)
{
	set ..currentFHIRService = pFHIRService
}

/// Intercept read interaction for ValueSet/CodeSystem
Method Read(pResourceType As %String, pResourceId As %String, pVersionId As %String = "") As %DynamicObject
{
	if (pResourceType = "ValueSet") || (pResourceType = "CodeSystem")
	{
		quit $classmethod(##class(iscru.fhir.fts.TerminologyInteractions).%ClassName(1), "read" _ pResourceType, ..currentFHIRService, pResourceId, pVersionId)
	}
	else
	{
		quit ##super(pResourceType, pResourceId, pVersionId)
	}
}

/// Intercept search interaction for ValueSet/CodeSystem
Method Search(pResourceType As %String, pCompartment As %String, pCompartmentId As %String, pParameters As HS.FHIRServer.API.Data.QueryParameters = "", ByRef pSortKeys = "") As HS.FHIRServer.Util.SearchResult
{
	if (pResourceType = "ValueSet") || (pResourceType = "CodeSystem")
	{
		#dim result As HS.FHIRServer.Util.SearchResult = $classmethod(##class(iscru.fhir.fts.TerminologyInteractions).%ClassName(1), "search" _ pResourceType, ..currentFHIRService, pCompartment, pCompartmentId, pParameters, .pSortKeys)
		
		// memorize the SearchResult being returned in order to intercept subsequent SearchIncludes() call		
		set ..lastSearchResult = result
		quit result
	}
	else
	{
		quit ##super(pResourceType, pCompartment, pCompartmentId, pParameters, .pSortKeys)
	}
}

/// Intercept _include/_revinclude processing for ValueSet/CodeSystem.
/// HS.FHIRServer.Service calls this method immediately after calling Search() - see SearchNew() method of HS.FHIRServer.Service.
Method SearchIncludes(pResultSet As HS.FHIRServer.Util.SearchResult, ByRef pIncludeArr, ByRef pRevIncludeArr)
{
	if $isObject(..lastSearchResult) && (..lastSearchResult = pResultSet)
	{
		set ..lastSearchResult = ""
		do ##class(iscru.fhir.fts.TerminologyInteractions).searchIncludes(..currentFHIRService, pResultSet, .pIncludeArr, .pRevIncludeArr)
	}
	else
	{
		do ##super(pResultSet, .pIncludeArr, .pRevIncludeArr)
	}
}

/// Intercept history interaction for ValueSet/CodeSystem
Method History(pResourceType As %String, pResourceId As %String, pSince As %String, pAt As %String) As HS.FHIRServer.Util.SearchResult
{
	if (pResourceType = "ValueSet") || (pResourceType = "CodeSystem")
	{
		quit $classmethod(##class(iscru.fhir.fts.TerminologyInteractions).%ClassName(1), "history" _ pResourceType, ..currentFHIRService, pResourceId, pSince, pAt)
	}
	else
	{
		quit ##super(pResourceType, pResourceId, pSince, pAt)
	}
}

/// Intercept GetVersionList() calls for ValueSet/CodeSystem.
/// This method is never called as of 2020.2.
Method GetVersionList(pResourceType As %String, pResourceId As %String, Output pCurrentVersionId) As %List
{
	if (pResourceType = "ValueSet") || (pResourceType = "CodeSystem")
	{
		quit $classmethod(##class(iscru.fhir.fts.TerminologyInteractions).%ClassName(1), "getVersionList" _ pResourceType, ..currentFHIRService, pResourceId, .pCurrentVersionId)
	}
	else
	{
		quit ##super(pResourceType, pResourceId, .pCurrentVersionId)
	}
}

}

