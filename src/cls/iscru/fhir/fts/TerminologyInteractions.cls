Include HS.FHIRServer

/// Read/search/history interactions for CodeSystem and ValueSet resources.
/// 
/// Search interaction:
///  - the only supported search parameter for both resources is "url" for now;
///  - if no url specified, then all available CodeSystems (or ValueSets) are returned, 
///      provided the current Strategy class overrides listCodeTableClasses() method;
///  - sorting is only supported on url: _sort=url or _sort=-url;
///  - paging is fully supported via FHIR framework of IRIS.
/// 
/// Currently *not* supported:
///  - history interaction and versioning in general (TODO);
///  - concept hierarchies (TODO);
///  - non-datatype properties (TODO);
///  - _summary/_include/_revinclude parameters.
/// 
Class iscru.fhir.fts.TerminologyInteractions [ Abstract ]
{

ClassMethod searchValueSet(pFHIRService As HS.FHIRServer.API.Service, pCompartment As %String, pCompartmentId As %String, pParameters As HS.FHIRServer.API.Data.QueryParameters = "", ByRef pSortKeys = "") As HS.FHIRServer.Util.SearchResult
{
	$$$FSLog("searchValueSet: " _ pCompartment _ "/" _ pCompartmentId) 		// _ "/" _ ##class(iscru.fhir.JSONUtils).obj2json(pParameters).Read())
	quit ..searchInternal(pFHIRService, "ValueSet", pCompartment, pCompartmentId, pParameters, .pSortKeys)
}

ClassMethod searchCodeSystem(pFHIRService As HS.FHIRServer.API.Service, pCompartment As %String, pCompartmentId As %String, pParameters As HS.FHIRServer.API.Data.QueryParameters = "", ByRef pSortKeys = "") As HS.FHIRServer.Util.SearchResult
{
	$$$FSLog("searchCodeSystem: " _ pCompartment _ "/" _ pCompartmentId)   //  _ "/" _ ##class(iscru.fhir.JSONUtils).obj2json(pParameters).Read()
	quit ..searchInternal(pFHIRService, "CodeSystem", pCompartment, pCompartmentId, pParameters, .pSortKeys)
}

/// _include/_revinclude parameters are not supported, and don't make much sense for CodeSystem/ValueSet search.
ClassMethod searchIncludes(pFHIRService As HS.FHIRServer.API.Service, pResultSet As HS.FHIRServer.Util.SearchResult, ByRef pIncludeArr, ByRef pRevIncludeArr)
{
	$$$FSLog("searchIncludes: " _ $get(pIncludeArr) _ "/" _ $get(pRevIncludeArr))
	if (+$get(pIncludeArr) '= 0) || (+$get(pRevIncludeArr) '= 0)
	{
		$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "_include/_revinclude not supported for ValueSet/CodeSystem")))
	}
}

/// This method implements search interaction for ValueSet/CodeSystem.
/// The only supported search parameter is "url" for now.
/// If no url specified, then all available CodeSystems (or ValueSets) are returned, 
/// provided the current Strategy class implements listCodeTableClasses() method.
/// Sorting is only supported on url.
/// 
/// pSortKeys: Array of sort keys:<br>
/// - pSortKeys(n)   = True if ascending order, False if descending<br>
/// - pSortKeys(n,"SearchParam") = The nth SearchParam object to be sorted on.<br>
/// 
ClassMethod searchInternal(pFHIRService As HS.FHIRServer.API.Service, pResourceType As %String, pCompartment As %String, pCompartmentId As %String, pParameters As HS.FHIRServer.API.Data.QueryParameters = "", ByRef pSortKeys = "") As HS.FHIRServer.Util.SearchResult [ Private ]
{
	if (pCompartment '= "") $$$ThrowFHIR($$$HSFHIRErrNotInCompartment, pCompartment, pResourceType, $$$OutcomeInvalid(400))
	
	// create result set to be returned
	#dim return As HS.FHIRServer.Util.SearchResult = ##class(HS.FHIRServer.Util.SearchResult).Create()

	// get url of the ValueSet/CodeSystem from the request
	// GetOneParameterValue() is supposed to throw $$$HSFHIRErrMultipleParameters if there are miltiple urls in the request -- to be fixed in 2020.3 or 2020.4? - see CreateFromCSPRequest method in HS.FHIRServer.API.Data.QueryParameters
	#dim modifier As %String = ""
	#dim url As %String = $zstrip(pParameters.GetOneParameterValue("url", .modifier), "<>W", $c(13,10))
	if (url '= "") && (modifier '= "")
	{ 
		$$$ThrowFHIR($$$HSFHIRErrUnsupportedParameterModifier, "url", modifier, $$$OutcomeNotSupported(400)) 
	}
	
	if (pResourceType = "CodeSystem")
	{
		// system === url
		#dim modifier2 As %String = ""
		#dim system As %String = $zstrip(pParameters.GetOneParameterValue("system", .modifier2), "<>W", $c(13,10))
		if (system '= "") && (modifier2 '= "")
		{ 
			$$$ThrowFHIR($$$HSFHIRErrUnsupportedParameterModifier, "system", modifier2, $$$OutcomeNotSupported(400)) 
		}
		
		if (url '= "") && (system '= "") && (url '= system)
		{
			// inconsistent params -> return empty result set
			quit return
		}
		
		if (url = "") && (system '= "")
		{
			set url = system
			set modifier = modifier2
		}
	}
	
	kill classIndex
	
	if (url '= "")
	{
		for i = 1:1:$length(url, ",")
		{
			#dim item As %String = $piece(url, ",", i)
			
			// determine code table class
			#dim className As %String = pFHIRService.strategy.determineCodeTableClassname(pResourceType, item)
			if (className = "") || '$$$comClassDefined(className) continue
			
			set classIndex(item) = className
		}
	}
	else
	{
		// output a list of all available ValueSets/CodeSystems
		
		#dim classes As %List = pFHIRService.strategy.listCodeTableClasses()
		if (classes = "")
		{
			$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "No url specified")))
		}
		
		#dim pointer As %Integer = 0
		set className = ""
		while $listnext(classes, pointer, className)
		{
			set url = $method(pFHIRService.strategy, "get" _ pResourceType _ "ForClassname", className)
			set classIndex(url) = className
		}
	}
	
	#dim urlSort As %Boolean = ..getOneParamSortOrder(.pSortKeys, "url")
	set url = ""
	for
	{
		set url = $order(classIndex(url), $case(urlSort, "":1, 1:1, 0:-1))
		if (url = "") quit
		do return.AddRow(pResourceType _ "/" _ classIndex(url), pResourceType, classIndex(url), 0, "match")
	}

	quit return
}

/// Get sort direction for <var>paramName</var> parameter from <var>pSortKeys</var> array which has been obtained from search request parameters.
/// Returns either 1 (ascending order), 0 (descending order) or an empty string (unsorted).
ClassMethod getOneParamSortOrder(ByRef pSortKeys, paramName As %String) As %Boolean [ Private ]
{
	#dim key As %String = ""
	for
	{
		set key = $order(pSortKeys(key))
		if (key = "")
		{
			return ""
		}
		elseif (pSortKeys(key, "SearchParam").name = paramName)
		{
			return pSortKeys(key)
		}
	}
}

/// This method implements read interaction for ValueSet.
ClassMethod readValueSet(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, pVersionId As %String = "") As %DynamicObject
{
	$$$FSLog("readValueSet: " _ pResourceId _ "/" _ pVersionId)
	if (pVersionId '= "") $$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "Versioning is not supported for ValueSet")))
	
	// NB: ValueSet's server id (pResourceId) equals the corresponding code table class name
	#dim className As %String = pResourceId
	
	// get ValueSet's canonical url
	#dim valueSet As %String = pFHIRService.strategy.getValueSetForClassname(className)
	
	if '$$$comClassDefined(className) || (valueSet = "")
	{
		$$$ThrowFHIR($$$HSFHIRErrResourceNotFound, "ValueSet", pResourceId, $$$OutcomeNotFound)
	}

	quit ..constructValueSetResource(pFHIRService, valueSet, className)
}

ClassMethod constructValueSetResource(fhirService As HS.FHIRServer.API.Service, url As %String, className As %String, composeIncluded As %Boolean = {$$$YES}) As %DynamicObject
{
	// NB: ValueSet's server id equals code table class name (className)
	
	// get CodeSystem's canonical url
	#dim codeSystem As %String = fhirService.strategy.determineCodeSystemForValueSet(url)
	if (codeSystem = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "CodeSystem not found for ValueSet.url=" _ url))
	
	#dim return As %DynamicObject = ##class(iscru.fhir.JSONUtils).getJsonFromXdata($classname(), "ValueSetTemplate")
	set return.id = className
	set return.url = url
	set return.name = className
	set return.description = $$$comClassKeyGet(className, $$$cCLASSdescription)
	if composeIncluded
	{
		set return.compose.include."0".system = codeSystem
	}
	else
	{
		do return.%Remove("compose")
	}

	quit return
}

/// This method implements read interaction for CodeSystem.
ClassMethod readCodeSystem(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, pVersionId As %String = "") As %DynamicObject
{
	$$$FSLog("readCodeSystem: " _ pResourceId _ "/" _ pVersionId)
	if (pVersionId '= "") $$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "Versioning is not supported for CodeSystem")))
	
	// NB: CodeSystem's server id (pResourceId) equals the corresponding code table class name
	#dim className As %String = pResourceId
	
	// get CodeSystem's canonical url
	#dim codeSystem As %String = pFHIRService.strategy.getCodeSystemForClassname(className)
	
	if '$$$comClassDefined(className) || (codeSystem = "")
	{
		$$$ThrowFHIR($$$HSFHIRErrResourceNotFound, "CodeSystem", pResourceId, $$$OutcomeNotFound)
	}
	
	#dim codeProp As %String = pFHIRService.strategy.getCodePropertyName(className)
	#dim displayProp As %String = pFHIRService.strategy.getDisplayPropertyName(className)
	
	if (codeProp = "") || (displayProp = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine class properties that map to CodeSystem.concept.code and CodeSystem.concept.display elements"))

	#dim return As %DynamicObject = ##class(iscru.fhir.JSONUtils).getJsonFromXdata($classname(), "CodeSystemTemplate")
	set return.id = className
	set return.url = codeSystem
	set return.name = className
	set return.description = $$$comClassKeyGet(className, $$$cCLASSdescription)
	
	// From https://www.hl7.org/fhir/R4/codesystem-definitions.html:
	//   CodeSystem.valueSet - Canonical reference to the value set that contains the entire code system.
	//   The definition of the value set SHALL include all codes from this code system and only codes from this code system, and it SHALL be immutable.
	set return.valueSet = pFHIRService.strategy.getValueSetForClassname(className)
	
	// Collect class properties to a multidim array - sorted by $$$cPROPsequencenumber -
	// excluding Collection, Internal, MultiDimensional, Private, Identity and object properties.
	// NB: exclude class properties which are mapped to concept.code and concept.display elements
	// TODO: support object properties - references to code tables.
	kill propArray
	do pFHIRService.strategy.getCodeTableProperties(className, $lb(codeProp, displayProp), .propArray)
	
	// construct "property" array: properties sorted according to $$$cPROPsequencenumber
	#dim position As %Integer = ""
	for
	{
		set position = $order(propArray(position))
		if (position = "") quit

		#dim property As %String = propArray(position, "name")
		#dim description As %String = propArray(position, "description")
		#dim fhirDataType As %String = propArray(position, "fhirDataType")
		
		#dim propItem As %DynamicObject = {"code": (property), "description": (description), "type": (fhirDataType)}
		do return.property.%Push(propItem)
	} // for
	
	// no properties found -> remove "property" element
	if (propArray = 0) do return.%Remove("property")
	
	// TODO: sort concepts according to some property of the class if required
	
	// loop through code table rows and construct "concept" array
	#dim rs As %ResultSet = ##class(%ResultSet).%New(className _ ":Extent")
	$$$ThrowOnError(rs.Execute())

	#dim total As %Integer = 0
	while (rs.Next())
	{
		#dim sc As %Status = $$$OK
		#dim item = $classmethod(className, "%OpenId", rs.GetData(1), 0, .sc)
		$$$ThrowOnError(sc)
		
		#dim conceptItem As %DynamicObject = $$$NewJSONObject
		
		set conceptItem.code = $property(item, codeProp)
		set conceptItem.display = $property(item, displayProp)
		
		// loop through properties in propArray
		set position = ""
		for
		{
			set position = $order(propArray(position))
			if (position = "") quit
			
			set property = propArray(position, "name")
			#dim value As %String = $property(item, property)
			
			// add property value to "property" array (non-empty values only!)
			if (value '= "")
			{
				set fhirDataType = propArray(position, "fhirDataType")
				#dim clientDataType As %String = propArray(position, "clientDataType")
				#dim valueElementName As %String = propArray(position, "valueElementName")

				if (clientDataType = "TIMESTAMP") set value = ##class(%TimeStamp).LogicalToXSD(value)
				if (clientDataType = "DATE") set value = ##class(%Date).LogicalToXSD(value)
				
				set propItem = $$$NewJSONObject
				set propItem.code = property
				do propItem.%Set(valueElementName, value, $case(fhirDataType, "boolean":"boolean", "decimal":"number", :""))

				// init "property" array if it is the first iteration
				if (conceptItem.property = "") set conceptItem.property = $$$NewJSONArray
								
				do conceptItem.property.%Push(propItem)
			}
		} // for
		
		do return.concept.%Push(conceptItem)
		set total = total + 1
		
	} // while
	
	if (total = 0) do return.%Remove("concept")
	set return.count = total

	quit return
}

ClassMethod historyValueSet(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, pSince As %String, pAt As %String) As HS.FHIRServer.Util.SearchResult
{
	$$$FSLog("historyValueSet: " _ pResourceId _ "/" _ pSince _ "/" _ pAt)
	$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "_history not supported for ValueSet")))
}

ClassMethod historyCodeSystem(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, pSince As %String, pAt As %String) As HS.FHIRServer.Util.SearchResult
{
	$$$FSLog("historyCodeSystem: " _ pResourceId _ "/" _ pSince _ "/" _ pAt)
	$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "_history not supported for CodeSystem")))
}

ClassMethod getVersionListValueSet(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, Output pCurrentVersionId) As %List
{
	$$$FSLog("getVersionListValueSet: " _ pResourceId)
	$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "GetVersionList() not supported for ValueSet")))
}

ClassMethod getVersionListCodeSystem(pFHIRService As HS.FHIRServer.API.Service, pResourceId As %String, Output pCurrentVersionId) As %List
{
	$$$FSLog("getVersionListCodeSystem: " _ pResourceId)
	$$$ThrowStatus($$$ADDSC(##class(iscru.fhir.FHIRUtils).#FHIR400STATUS, $$$ERROR($$$GeneralError, "GetVersionList() not supported for CodeSystem")))
}

XData ValueSetTemplate [ MimeType = application/json ]
{
{
	"resourceType": "ValueSet",
	"id": "<replaced at runtime>",
	"url": "<replaced at runtime>",
	"name": "<replaced at runtime>",
	"status": "active",
	"description": "<replaced at runtime>",
	"immutable": "true",
	"compose" : {
		"include": [{
			"system": "<replaced at runtime>"
		}]
	}
}
}

XData CodeSystemTemplate [ MimeType = application/json ]
{
{
	"resourceType": "CodeSystem",
	"id": "<replaced at runtime>",
	"url": "<replaced at runtime>",
	"name": "<replaced at runtime>",
	"status": "active",
	"description": "<replaced at runtime>",
	"valueSet": "<replaced at runtime>",
	"content": "complete",
	"count": "<replaced at runtime>",
	"property": [],
	"concept": []
}
}

}

