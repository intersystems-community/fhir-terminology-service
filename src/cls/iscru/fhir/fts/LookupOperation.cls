Include HS.FHIRServer

/// CodeSystem/$lookup operation based on FHIR R4 spec - see https://www.hl7.org/fhir/R4/codesystem-operation-lookup.html
/// Currently code and system are the only supported input parameters.
///  
/// TODO: support non-datatype properties, versioning, hierarchies, inactive codes
/// 
Class iscru.fhir.fts.LookupOperation Extends (%RegisteredObject, HS.FHIRServer.Util.FHIRQueryUtils)
{

/// FHIR standard $lookup's OperationDefinition URI = http://hl7.org/fhir/OperationDefinition/CodeSystem-lookup
/// TODO: make available custom OperationDefinition (with the URI below) limiting input parameter set to the supported ones only.
Parameter operationDefinitionURI = "urn:OperationDefinition:CodeSystem-lookup";

Parameter lookupInputPARAMS = {$lb("code", "system")};

/// This method is not going to be ever called. See Operations and CapabilityTemplate classes.
/// @API Enumerate the name and url of each Operation supported by this class
ClassMethod AddSupportedOperations(pMap As %DynamicObject)
{
	do pMap.%Set("lookup", ..#operationDefinitionURI)
}

/// Implementation of $lookup (Type scope - requires type)
ClassMethod FHIRTypeOpLookup(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	do ..%New().processLookup(pService, pRequest, pResponse)
}

Method processLookup(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, ByRef pResponse As HS.FHIRServer.API.Data.Response) [ Private ]
{
	#define FHIR400STATUS ##class(iscru.fhir.FHIRUtils).#FHIR400STATUS
	
	if (pRequest.Type '= "CodeSystem")
	{
		$$$ThrowFHIR($$$HSFHIRErrOperationNotSupported, "$" _ pRequest.OperationName, pRequest.Type _ " (" _ pRequest.OperationScope _ ")", $$$OutcomeNotSupported(400))
	}
	
	// extract input parameters: code and system
	// NB: not more than one instance of each supported parameter is expected
	kill params
	do ##class(iscru.fhir.FHIRUtils).extractOperationParameters(pRequest, ..#lookupInputPARAMS, $$$YES, .params)
	
	#dim code As %String = $get(params("code", 1))  // the code that is to be located
	#dim system As %String = $get(params("system", 1))  // canonical uri of the CodeSystem
	
	// code and system are required
	if (code = "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "code parameter missing from $" _ pRequest.OperationName _ " interaction")))
	if (system = "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "system parameter missing from $" _ pRequest.OperationName _ " interaction")))

	// determine code table class and sql table name
	#dim table As %String = ""
	#dim className As %String = pService.strategy.determineCodeTableClassname("CodeSystem", system, .table)
	if (className = "") || '$$$comClassDefined(className) $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Class not found for CodeSystem.url=" _ system)))
	if (table = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "SQL table not found for CodeSystem.url=" _ system))
	
	#dim codeProp As %String = pService.strategy.getCodePropertyName(className)
	#dim displayProp As %String = pService.strategy.getDisplayPropertyName(className)
	
	if (codeProp = "") || (displayProp = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine class properties that map to CodeSystem.concept.code and CodeSystem.concept.display elements"))
	
	// determine SQL field name for "code" property
	#dim codeField As %String = $$quoter2^%apiSQL($$$comMemberKeyGet(className, $$$cCLASSproperty, codeProp, $$$cPROPsqlfieldname))

	kill sqlParams
	set sqlParams($i(sqlParams)) = code
	#dim sql As %String = "SELECT TOP 1 %id FROM " _ table _ " WHERE " _ codeField _ " = ?"
	#dim sqlResultSet As %SQL.StatementResult = ..runQuery(sql, .sqlParams)
	
	if 'sqlResultSet.%Next() $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Code """ _ code _ """ not found in " _ system)))
	
	#dim sc As %Status = $$$OK
	#dim obj As %Persistent = $classmethod(className, "%OpenId", sqlResultSet.%GetData(1), 0, .sc)
	$$$ThrowOnError(sc)
	
	
	#dim return As %DynamicObject = $$$NewJSONObject
	set return.resourceType = "Parameters"
	set return.parameter = $$$NewJSONArray
	do return.parameter.%Push({"name": "name", "valueString": (className)})  // A display name for the code system
	do return.parameter.%Push({"name": "display", "valueString": ($property(obj, displayProp))})  // The preferred display for this concept
	
	set pResponse.Json = return
	set pResponse.Status = 200
	
	// Collect class properties to a multidim array - sorted by $$$cPROPsequencenumber -
	// excluding Collection, Internal, MultiDimensional, Private, Identity and object properties.
	// NB: exclude properties which are mapped to concept.code and concept.display elements
	// TODO: support object properties - references to code tables.
	kill propArray
	do pService.strategy.getCodeTableProperties(className, $lb(codeProp, displayProp), .propArray)

	// if no properties found, then we are done!	
	if ($get(propArray) = 0) quit
	

	// loop through properties in propArray and add items to output Parameters
	#dim position As %Integer = ""
	for
	{
		set position = $order(propArray(position))
		if (position = "") quit
		
		#dim property As %String = propArray(position, "name")
		#dim value As %String = $property(obj, property)
		if (value = "") continue  // skip empty values!
		
		#dim fhirDataType As %String = propArray(position, "fhirDataType")
		#dim clientDataType As %String = propArray(position, "clientDataType")
		#dim valueElementName As %String = propArray(position, "valueElementName")
		
		if (clientDataType = "TIMESTAMP") set value = ##class(%TimeStamp).LogicalToXSD(value)
		if (clientDataType = "DATE") set value = ##class(%Date).LogicalToXSD(value)

		#dim prop As %DynamicObject = $$$NewJSONObject
		set prop.name = "property"
		set prop.part = $$$NewJSONArray
		
		#dim propCode As %DynamicObject = $$$NewJSONObject
		set propCode.name = "code"
		set propCode.valueCode = property
		do prop.part.%Push(propCode)
		
		#dim propVal As %DynamicObject = $$$NewJSONObject
		set propVal.name = "value"
		do propVal.%Set(valueElementName, value, $case(fhirDataType, "boolean":"boolean", "decimal":"number", :""))
		do prop.part.%Push(propVal)
		
		do return.parameter.%Push(prop)
	} // for
}

}

