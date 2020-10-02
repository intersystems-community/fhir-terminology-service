Include HS.FHIRServer

/// CodeSystem/$validate-code and ValueSet/$validate-code operations based on FHIR R4 specs:
///   https://www.hl7.org/fhir/R4/codesystem-operation-validate-code.html
///   https://www.hl7.org/fhir/R4/valueset-operation-validate-code.html
/// 
/// Currently url, code, system and display are the only supported input parameters.
///  
/// TODO: support versioning, support more input parameters
/// 
Class iscru.fhir.fts.ValidateCodeOperation Extends (%RegisteredObject, HS.FHIRServer.Util.FHIRQueryUtils)
{

/// FHIR standard $validate-code's OperationDefinition URIs are
///    http://hl7.org/fhir/OperationDefinition/CodeSystem-validate-code
///    http://hl7.org/fhir/OperationDefinition/ValueSet-validate-code
/// TODO: make available custom OperationDefinitions limiting input parameter set to the supported ones only.
Parameter operationDefinitionURI = "urn:OperationDefinition:CodeSystem-validate-code";

Parameter operationDefinitionURI2 = "urn:OperationDefinition:ValueSet-validate-code";

Parameter validateCodeSystemInputPARAMS = {$lb("url", "code", "display")};

Parameter validateValueSetInputPARAMS = {$lb("url", "code", "system", "display")};

/// This method is not going to be ever called. See Operations and CapabilityTemplate classes.
/// @API Enumerate the name and url of each Operation supported by this class
ClassMethod AddSupportedOperations(pMap As %DynamicObject)
{
	do pMap.%Set("validate-code", ..#operationDefinitionURI)
	//do pMap.%Set("validate-code", ..#operationDefinitionURI2)
}

/// Type scope
ClassMethod FHIRTypeOpValidateCode(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	do ..%New().processValidateCode(pService, pRequest, pResponse)
}

/// Instance scope
ClassMethod FHIRInstanceOpValidateCode(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	do ..FHIRTypeOpValidateCode(pService, pRequest, pResponse)
}

Method processValidateCode(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, ByRef pResponse As HS.FHIRServer.API.Data.Response) [ Private ]
{
	#define FHIR400STATUS ##class(iscru.fhir.FHIRUtils).#FHIR400STATUS
	
	if (pRequest.Type '= "CodeSystem") && (pRequest.Type '= "ValueSet")
	{
		$$$ThrowFHIR($$$HSFHIRErrOperationNotSupported, "$" _ pRequest.OperationName, pRequest.Type _ " (" _ pRequest.OperationScope _ ")", $$$OutcomeNotSupported(400))
	}
	
	/////////// extract input parameters: url, code, system, display ("system" is only applicable to ValueSet/$validate-code)
	
	// NB: not more than one instance of each supported parameter is expected
	#dim supportedParams As %List = $case(pRequest.Type, "CodeSystem":..#validateCodeSystemInputPARAMS, "ValueSet":..#validateValueSetInputPARAMS)
	kill params
	do ##class(iscru.fhir.FHIRUtils).extractOperationParameters(pRequest, supportedParams, $$$YES, .params)
	
	// url is required in case of type level call
	#dim url As %String = $get(params("url", 1))
	if (pRequest.Id = "") && (url = "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "url parameter missing from $" _ pRequest.OperationName _ " interaction")))
	if (pRequest.Id '= "") && (url '= "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "url parameter is not supported for instance level calls to $" _ pRequest.OperationName)))
	
	// code is required as coding and codeableConcept are not supported: "One (and only one) of the in parameters code, coding, or codeableConcept must be provided."
	#dim code As %String = $get(params("code", 1))  // The code that is to be validated
	if (code = "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "code parameter missing from $" _ pRequest.OperationName _ " interaction")))
	
	#dim system As %String = $get(params("system", 1))  // The system for the code that is to be validated (applicable to ValueSet/$validate-code only)
	#dim display As %String = $get(params("display", 1))  // The display associated with the code, if provided.
	
	if (pRequest.Type = "ValueSet") && (system = "")
	{
		// "If a code is provided, a system or a context must be provided"
		$$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "system parameter missing from $" _ pRequest.OperationName _ " interaction")))
	}
	
	/////////// determine code table class and sql table name
	
	#dim className As %String = ""
	#dim table As %String = ""
	
	if (pRequest.Id = "")
	{
		// type level call
		set className = pService.strategy.determineCodeTableClassname(pRequest.Type, url, .table)
		if (className = "") || '$$$comClassDefined(className) $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Class not found: " _ className)))
		if (table = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "SQL table not found for " _ pRequest.Type _ ".url=" _ url))
	}
	else
	{
		// instance level call
		set className = pRequest.Id
		if '$$$comClassDefined(className) $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Class not found: " _ className)))
		
		if (pRequest.Type = "CodeSystem")
		{
			set url = pService.strategy.getCodeSystemForClassname(className)
		}
		else
		{
			set url = pService.strategy.getValueSetForClassname(className)
		}
		if (url = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine " _ pRequest.Type _ ".url for " _ className))

		do pService.strategy.determineCodeTableClassname(pRequest.Type, url, .table)
		if (table = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "SQL table not found for " _ pRequest.Type _ "/" _ pRequest.Id))
	}
	
	/////////// get names of the properties that correspond to code and display
	
	#dim codeProp As %String = pService.strategy.getCodePropertyName(className)
	#dim displayProp As %String = pService.strategy.getDisplayPropertyName(className)
	
	if (codeProp = "") || (displayProp = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine class properties that map to CodeSystem.concept.code and CodeSystem.concept.display elements"))
	
	// determine SQL field name for "code" property
	#dim codeField As %String = $$quoter2^%apiSQL($$$comMemberKeyGet(className, $$$cCLASSproperty, codeProp, $$$cPROPsqlfieldname))
	
	/////////// prepare response
	
	set pResponse.Status = 200
	set pResponse.Json = $$$NewJSONObject
	set pResponse.Json.resourceType = "Parameters"
	set pResponse.Json.parameter = $$$NewJSONArray
	
	#dim result As %DynamicObject = $$$NewJSONObject
	set result.name = "result"
	do pResponse.Json.parameter.%Push(result)
	
	/////////// check system
	
	if (pRequest.Type = "ValueSet") && (system '= "")
	{
		#dim codeSystemUrl As %String = pService.strategy.determineCodeSystemForValueSet(url)
		if (system '= codeSystemUrl)
		{
			#dim wrongSystem As %DynamicObject = $$$NewJSONObject
			set wrongSystem.name = "message"
			set wrongSystem.valueString = "Code system '" _ system _ "' is inconsistent with value set '" _ url _ "'"
			do pResponse.Json.parameter.%Push(wrongSystem)

			do result.%Set("valueBoolean", $$$NO, "boolean")			
			quit
		}
	}
	
	/////////// run SQL query to get object id for the code table

	kill sqlParams
	set sqlParams($i(sqlParams)) = code
	#dim sql As %String = "SELECT TOP 1 %id FROM " _ table _ " WHERE " _ codeField _ " = ?"
	#dim sqlResultSet As %SQL.StatementResult = ..runQuery(sql, .sqlParams)
	
	/////////// code not found?
			
	if 'sqlResultSet.%Next()
	{
		#dim notFound As %DynamicObject = $$$NewJSONObject
		set notFound.name = "message"
		set notFound.valueString = "Unable to find code '" _ code _ "' in " _ pRequest.Type _ " '" _ url _ "'"
		do pResponse.Json.parameter.%Push(notFound)

		do result.%Set("valueBoolean", $$$NO, "boolean")		
		quit
	}
	
	/////////// check display
	
	#dim objectId As %String = sqlResultSet.%GetData(1)
	#dim actualDisplay As %String = $classmethod(className, displayProp _ "GetStored", objectId)
	
	if (display '= "") && (display '= actualDisplay)
	{
		#dim wrongDisplay As %DynamicObject = $$$NewJSONObject
		set wrongDisplay.name = "message"
		set wrongDisplay.valueString = "The display '" _ display _ "' is not a valid display for the code '" _ code _ "'"
		do pResponse.Json.parameter.%Push(wrongDisplay)
		
		// although display is not valid, return result=true - according to established practice
	}

	/////////// return actual display and result=true

	if (display = "") || (display '= actualDisplay) do pResponse.Json.parameter.%Push({"name": "display", "valueString": (actualDisplay)})
	
	do result.%Set("valueBoolean", $$$YES, "boolean")
}

}

