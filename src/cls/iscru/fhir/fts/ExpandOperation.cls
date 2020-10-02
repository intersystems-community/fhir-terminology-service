Include HS.FHIRServer

/// ValueSet/$expand operation based on FHIR R4 spec - see https://www.hl7.org/fhir/R4/valueset-operation-expand.html
/// Currently url, filter, offset, count and sort are the only supported input parameters.
/// 
/// filter = SQL LIKE pattern that is applied to code and display properties of the code table class 
///   (when testing HTTP GET from browser or in Postman beware that url-encoded percent sign looks like %25)
/// offset = number of codes to skip (defaults to 0)
/// count = number of codes to return (if count>0)
/// FHIR R4 spec: If count=0, the client is asking how large the expansion is. Servers SHOULD honor this request for hierarchical expansions as well, and simply return the overall count.
/// 
/// sort is a custom parameter - not from FHIR R4 spec for $expand.
/// It can contain a comma-separated list of sort rules in priority order.
/// Each item in the list is a case-sensitive name of a property within ValueSet's source code table class.
/// Each item can be optionally prefixed with '-'.
/// The prefix indicates decreasing order; in its absence, the parameter is applied in increasing order.
/// 
/// TODO: support versioning, hierarchies, inactive codes
/// 
Class iscru.fhir.fts.ExpandOperation Extends (%RegisteredObject, HS.FHIRServer.Util.FHIRQueryUtils)
{

/// FHIR standard $expand's OperationDefinition URI = http://hl7.org/fhir/OperationDefinition/ValueSet-expand
/// TODO: make available custom OperationDefinition (with the URI below) limiting input parameter set to the supported ones only.
Parameter operationDefinitionURI = "urn:OperationDefinition:ValueSet-expand";

Parameter expandInputPARAMS = {$lb("url", "filter", "sort", "offset", "count")};

/// This method is not going to be ever called. See Operations and CapabilityTemplate classes.
/// @API Enumerate the name and url of each Operation supported by this class
ClassMethod AddSupportedOperations(pMap As %DynamicObject)
{
	do pMap.%Set("expand", ..#operationDefinitionURI)
}

/// Type scope
ClassMethod FHIRTypeOpExpand(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	do ..%New().processExpand(pService, pRequest, pResponse)
}

/// Instance scope
ClassMethod FHIRInstanceOpExpand(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, pResponse As HS.FHIRServer.API.Data.Response)
{
	do ..FHIRTypeOpExpand(pService, pRequest, pResponse)
}

Method processExpand(pService As HS.FHIRServer.API.Service, pRequest As HS.FHIRServer.API.Data.Request, ByRef pResponse As HS.FHIRServer.API.Data.Response) [ Private ]
{
	#define FHIR400STATUS ##class(iscru.fhir.FHIRUtils).#FHIR400STATUS
	
	if (pRequest.Type '= "ValueSet")
	{
		$$$ThrowFHIR($$$HSFHIRErrOperationNotSupported, "$" _ pRequest.OperationName, pRequest.Type _ " (" _ pRequest.OperationScope _ ")", $$$OutcomeNotSupported(400))
	}
	
	/* 
	// debugging: output request properties
	
	#dim stream As %Stream.Object = ##class(iscru.fhir.JSONUtils).obj2json(pRequest)
	//#dim r as %DynamicObject = ##class(%DynamicAbstractObject).%FromJSON(stream)
	do stream.Rewind()
	set return.description = $tr(stream.Read($$$MaxLocalLength), """", "")
	*/
	
	// extract input parameters
	// NB: only one instance of each supported parameter is expected
	kill params
	do ##class(iscru.fhir.FHIRUtils).extractOperationParameters(pRequest, ..#expandInputPARAMS, $$$YES, .params)
	
	// url is required in case of type level call
	#dim url As %String = $get(params("url", 1))
	if (pRequest.Id = "") && (url = "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "url parameter missing from $" _ pRequest.OperationName _ " interaction")))
	if (pRequest.Id '= "") && (url '= "") $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "url parameter is not supported for instance level calls to $" _ pRequest.OperationName)))
	
	#dim filter As %String = $get(params("filter", 1))
	#dim sort As %String = $get(params("sort", 1))
	#dim offset As %Integer = +$get(params("offset", 1), 0) // default 0
	#dim count As %Integer = $get(params("count", 1))
	
	// validate count
	if (count '= "") && ((+count < 0) || (count '= (+count))) $$$ThrowFHIR($$$HSFHIRErrInvalidParameterValue, "count", count, $$$OutcomeInvalid(400))

	#dim isZeroCount As %Boolean = (count = "0")
	
	// if count=0, then offset and sort don't make any sense
	if isZeroCount && ((offset '= 0) || (sort '= ""))
	{
		$$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Zero value of count is not consistent with ""offset"" or ""sort"" parameters present")))
	}

	// determine code table class and sql table name
	#dim className As %String = ""
	#dim table As %String = ""
	
	if (pRequest.Id = "")
	{
		// type level call
		set className = pService.strategy.determineCodeTableClassname("ValueSet", url, .table)
		if (className = "") || '$$$comClassDefined(className) $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Class not found: " _ className)))
		if (table = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "SQL table not found for ValueSet.url=" _ url))
	}
	else
	{
		// instance level call
		set className = pRequest.Id
		if '$$$comClassDefined(className) $$$ThrowStatus($$$ADDSC($$$FHIR400STATUS, $$$ERROR($$$GeneralError, "Class not found: " _ className)))
		
		set url = pService.strategy.getValueSetForClassname(className)
		if (url = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine ValueSet.url for " _ className))

		do pService.strategy.determineCodeTableClassname("ValueSet", url, .table)
		if (table = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "SQL table not found for ValueSet/" _ pRequest.Id))
	}
	
	// validate sort and construct column list for ORDER BY clause
	#dim orderByList As %String = ""
	if (sort '= "") set orderByList = ..constructOrderBy(className, sort)
	
	#dim codeProp As %String = pService.strategy.getCodePropertyName(className)
	#dim displayProp As %String = pService.strategy.getDisplayPropertyName(className)
	
	if (codeProp = "") || (displayProp = "") $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot determine class properties that map to CodeSystem.concept.code and CodeSystem.concept.display elements"))
	
	// construct WHERE clause conditions
	#dim whereConditions As %String = ""
	if (filter '= "") set whereConditions = ..constructWhere(filter, className, codeProp, displayProp)

	#dim return as %DynamicObject = ##class(iscru.fhir.fts.TerminologyInteractions).constructValueSetResource(pService, url, className, $$$NO)  // $$$NO = do not include "compose" element
	set return.expansion = $$$NewJSONObject
	set return.expansion.identifier = "urn:uuid:" _ $zconvert($SYSTEM.Util.CreateGUID(), "L")
	set return.expansion.timestamp = ##class(%TimeStamp).LogicalToXSD($ZDATETIME($ZTIMESTAMP, 3, 1, 3)) // GMT date/time
	
	// add expansion.parameter array
	// FHIR R4 spec (https://www.hl7.org/fhir/R4/valueset-definitions.html#ValueSet.expansion.offset):
	//  "The server decides which parameters to include here, but at a minimum, 
	//  the list SHOULD include all of the parameters that affect the $expand operation. 
	//  If the expansion will be persisted all of these parameters SHALL be included. 
	//  If the codeSystem on the server has a specified version then this version SHALL be provided 
	//  as a parameter in the expansion (note that not all code systems have a version)."
	set return.expansion.parameter = $$$NewJSONArray
	do return.expansion.parameter.%Push({"name": "offset", "valueInteger": (offset)})
	if (count '= "") do return.expansion.parameter.%Push({"name": "count", "valueInteger": (count)})
	if (filter '= "") do return.expansion.parameter.%Push({"name": "filter", "valueString": (filter)})
	if (sort '= "") do return.expansion.parameter.%Push({"name": "sort", "valueString": (sort)})

	#dim total As %Integer = 0
	
	if isZeroCount || (count '= "")
	{
		// get total number of records
		
		#dim countSql As %String = "SELECT count(1) FROM " _ table _ $case(whereConditions, "":"", :" WHERE " _ whereConditions)
		#dim countSqlResultSet As %SQL.StatementResult = ..runQuery(countSql)

		if 'countSqlResultSet.%Next() $$$ThrowStatus($$$ERROR($$$GeneralError, "Error getting total number of code table records"))
		set total = countSqlResultSet.%GetData(1)
	}
		
	if 'isZeroCount
	{
		#dim top As %String = $case(count, "":"", :" TOP " _ (offset + count))
		#dim where As %String = $case(whereConditions, "":"", :" WHERE " _ whereConditions)
		#dim orderby As %String = $case(orderByList, "":"", :" ORDER BY " _ orderByList)
		
		#dim sql As %String = "SELECT " _ top _ " %id FROM " _ table _ where _ orderby
		#dim sqlResultSet As %SQL.StatementResult = ..runQuery(sql)

		#dim system As %String = pService.strategy.determineCodeSystemForValueSet(url)
		#dim i As %Integer = 0
		while (sqlResultSet.%Next())
		{
			if (count = "") set total = total + 1  // if non-empty count, then we have already determined total number of records (see above)

			set i = i + 1			
			if (offset >= i) continue
			if (count '= "") && ((i - offset) > +count) quit

			#dim id As %Integer = sqlResultSet.%GetData(1)
			
			#dim jsItem As %DynamicObject = $$$NewJSONObject
			set jsItem.system = system
			
			//#dim item = $classmethod(className, "%OpenId", id, 0, .sc)
			//$$$ThrowOnError(sc)
			
			set jsItem.code = $classmethod(className, codeProp _ "GetStored", id) // $property(item, codeProp)
			set jsItem.display = $classmethod(className, displayProp _ "GetStored", id) // $property(item, displayProp)
			
			if ((i - offset) = 1) set return.expansion.contains = $$$NewJSONArray
			do return.expansion.contains.%Push(jsItem)
		}
	}
	
	set return.expansion.total = total
	set return.expansion.offset = offset

	set pResponse.Json = return
	set pResponse.Status = 200
}

/// Construct SQL WHERE clause conditions as per "filter" parameter, 
///  which is expected to contain SQL LIKE pattern to be applied to code and display properties
ClassMethod constructWhere(filter As %String, className As %String, codeProp As %String, displayProp As %String) As %String [ Private ]
{
	if (filter = "") quit ""
	set filter = $replace(filter, "'", "''")
	
	#dim codeColumn As %String = $$quoter2^%apiSQL($$$comMemberKeyGet(className, $$$cCLASSproperty, codeProp, $$$cPROPsqlfieldname))
	#dim displayColumn As %String = $$quoter2^%apiSQL($$$comMemberKeyGet(className, $$$cCLASSproperty, displayProp, $$$cPROPsqlfieldname))
	
	quit "(" _ codeColumn _ " LIKE '" _ filter _ "' OR " _ displayColumn _ " LIKE '" _ filter _ "')"
}

/// Validate sort parameter and return column list for ORDER BY.
ClassMethod constructOrderBy(className As %String, sort As %String) As %String [ Private ]
{
	if (sort = "") quit ""
	
	#dim orderBy As %String = ""
	kill sortColumns
	
	for i = 1:1:$length(sort, ",") 
	{
		#dim item As %String = $zstrip($piece(sort, ",", i), "<>W")
		if (item = "") $$$ThrowFHIR($$$HSFHIRErrInvalidSortKey, sort, $$$OutcomeInvalid(400))
		
		#dim isAscending As %Boolean = $$$YES
		if ($extract(item) = "-")
		{
			set isAscending = $$$NO
			set item = $extract(item, 2, *)
		}
		
		#dim column As %String = $$$comMemberKeyGet(className, $$$cCLASSproperty, item, $$$cPROPsqlfieldname)
		if (column = "") $$$ThrowFHIR($$$HSFHIRErrUnsupportedSortKey, item, $$$OutcomeNotSupported(400))
		
		if $data(sortColumns(column)) $$$ThrowFHIR($$$HSFHIRErrDuplicateSortKey, item, $$$OutcomeInvalid(400))
		set sortColumns(column) = ""
		
		set orderBy = orderBy _ $$quoter2^%apiSQL(column) _ $case(isAscending, $$$NO:" DESC", :"") _ ","
	}
	
	quit $zstrip(orderBy, "<>", ",")
}

}

