Include HS.FHIRServer

/// Container class for FHIR utility methods, parameters etc.
Class iscru.fhir.FHIRUtils [ Abstract ]
{

/// $$$ERROR($$$HSFHIRErrValidationFailure, $$$OutcomeInvalid(400))
Parameter FHIR400STATUS = {$$$ERROR("<HSFHIRErr>ValidationFailure", "|400|error|invalid")};

/// Need to run this method to enable any modifications made to custom Strategy or other related classes.
/// <var>fhirEndpoint</var> = web app path.
/// do ##class(iscru.fhir.FHIRUtils).reset("/csp/healthshare/myNS/fhir/r4")
ClassMethod reset(fhirEndpoint As %String)
{
	#dim strategy As HS.FHIRServer.API.InteractionsStrategy = ##class(HS.FHIRServer.API.InteractionsStrategy).GetStrategyForEndpoint(fhirEndpoint)
	do ##class(HS.FHIRServer.Service).InvalidateInstances(strategy.InstanceKey)   // InstanceKey is an integer
}

/// Extract values of the request parameters which names are listed in <var>supportedParams</var>
///     1) from Parameters resource expected in HTTP request body in case of HTTP POST, 
///  or 2) from query (URL) parameters - if there is no request body.
/// Return a multidim array: return([param name], [value count]) = [value].
/// An exception is thrown if any unsupported parameters are present.
/// If <var>singleValueOnly</val> is TRUE then an exception is thrown if more than one value of any parameter is present.
/// If <var>scalarValueOnly</val> is TRUE then an exception is thrown if a non-scalar paramter value is present within Parameters resource.
/// An exception is thrown if a modifier is present for any of the query (URL) parameters.
ClassMethod extractOperationParameters(request As HS.FHIRServer.API.Data.Request, supportedParams As %List, singleValueOnly As %Boolean = {$$$YES}, Output return, scalarValueOnly As %Boolean = {$$$YES})
{
	kill return
	
	#dim payload As %DynamicObject = request.Json

	if (payload '= "")
	{
		// NB: if there is a payload, then ignore query (URL) parameters
		
		#dim iter As %Iterator.Object = payload.parameter.%GetIterator()
		#dim entry As %DynamicObject
		while iter.%GetNext(.i, .entry)
		{
			if singleValueOnly && $data(return(entry.name))
			{
				// duplicate!
				$$$ThrowFHIR($$$HSFHIRErrMultipleParameters, entry.name, $$$OutcomeInvalid(400))
			}
			elseif '$listFind(supportedParams, entry.name)
			{
				// unsupported parameter found
				$$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Input parameter '" _ entry.name _ "' is not supported for $" _ request.OperationName _ " interaction")))
			}

			#dim iter2 As %Iterator.Object = entry.%GetIterator()
			#dim val = ""
			#dim found As %Boolean = $$$NO
			while iter2.%GetNext(.elName, .elVal)
			{
				if ((elName [ "value") && ($piece(elName, "value", 1) = "")) || (elName = "resource") || (elName = "part")
				{
					// check constraint: http://hl7.org/fhir/r4/parameters.html#invs
					if found $$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "A parameter must have one and only one of (value, resource, part): " _ entry.name)))
					
					set val = elVal  // assuming val is %DynamicArray for "part"
					set found = $$$YES
				}
			}
			
			// check constraint: http://hl7.org/fhir/r4/parameters.html#invs
			if 'found $$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "A parameter must have one and only one of (value, resource, part): " _ entry.name)))
			
			if scalarValueOnly && $isObject(val)
			{
				$$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Input parameter '" _ entry.name _ "' contains a non-scalar value")))
			}

			set return(entry.name, $i(return(entry.name))) = val
		}
	}
	else
	{
		// if there's no payload, then process query (URL) parameters
		
		for i = 1:1:$listLength(supportedParams)
		{
			#dim paramName As %String = $listGet(supportedParams, i)
			
			kill params
			do request.Parameters.GetParameters(paramName, .params)
			if singleValueOnly && (params > 1) $$$ThrowFHIR($$$HSFHIRErrMultipleParameters, paramName, $$$OutcomeInvalid(400))
			
			for j = 1:1:params
			{
				// NB: all query (URL) parameters are expected to have NO modifiers
				if (params(j).modifier '= "") $$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Modifiers are not supported for " _ paramName _ " parameter")))

				// clear leading/trailing whitespace (useful for query params)
				set return(paramName, $i(return(paramName))) = $zstrip(params(j).value, "<>W", $c(13,10))
			}
		} // for
		
		// verify that no unsupported query (URL) parameters are present in the request
		for i = 1:1:request.Parameters.Count()
		{
			#dim searchQueryParameter As HS.FHIRServer.API.SearchQueryParameter = request.Parameters.GetAt(i)
			set paramName = searchQueryParameter.name
				
			if '$listFind(supportedParams, paramName)
			{
				$$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Query parameter '" _ paramName _ "' is not supported for $" _ request.OperationName _ " interaction")))
			}
		} // for
	}
}

/// Return the value of a specified query (URL) parameter instance.
/// Leading/trailing whitespace is cleared.
/// An exception is thrown if a modifier is present for the parameter.
/// An exception is supposed to be thrown if more than one value is present.
ClassMethod getOneParameterValueNoModifier(paramName As %String, parameters As HS.FHIRServer.API.Data.QueryParameters) As %String
{
	#dim modifier As %String
	#dim return As %String = $zstrip(parameters.GetOneParameterValue(paramName, .modifier), "<>W", $c(13,10))
	if (return '= "") && (modifier '= "") $$$ThrowStatus($$$ADDSC(..#FHIR400STATUS, $$$ERROR($$$GeneralError, "Modifiers are not supported for " _ paramName _ " parameter")))
	
	/*
	// convert non-latin (e.g. Cyrillic) characters from UTF-8
	if (return '= "") set return = $zcvt(return, "I", "UTF8")
	*/
	
	quit return
}

/// Return resource's identifier element of the given type (code/system).
/// Assumption: identifier.type.coding array has only one entry for each of the identifiers of the resource.
/// If <var>typeSystem</var> is empty then only identifier.type.coding.code is used when looking up identifier of the given type.
/// The first found identifier is returned.
ClassMethod getIdentifierOfType(resource As %DynamicObject, typeCode As %String, typeSystem As %String = "") As %DynamicObject
{
	if 'resource.%IsDefined("identifier") || (resource.%GetTypeOf("identifier") '= "array") quit ""
	
	#dim iter As %Iterator.Object = resource.identifier.%GetIterator()
	#dim ident As %DynamicObject
	while iter.%GetNext(.key, .ident)
	{
		if (ident.type.coding."0".code = typeCode) && ((typeSystem = "") || (ident.type.coding."0".system = typeSystem))
		{
			return ident
		}		
	}
	
	quit ""
}

/// Return array item with the specified id.
ClassMethod getArrayItemById(array As %DynamicArray, id As %String, Output key) As %DynamicObject
{
	#dim iter As %Iterator.Object = array.%GetIterator()
	while iter.%GetNext(.key, .item)
	{
		if (item.id = id) return item
	}
	
	quit ""
}

/// Return array item with the specified url. To be used with extension arrays.
ClassMethod getArrayItemByUrl(array As %DynamicArray, url As %String, Output key) As %DynamicObject
{
	#dim iter As %Iterator.Object = array.%GetIterator()
	while iter.%GetNext(.key, .item)
	{
		if (item.url = url) return item
	}
	
	quit ""
}

/// Count array items with the specified name.
/// This method is intended to be used with "parameter" array of Parameters resource.
ClassMethod countArrayItemsByName(array As %DynamicArray, name As %String) As %Integer
{
	#dim count As %Integer = 0
	#dim entry As %DynamicObject
	#dim iter As %Iterator.Object = array.%GetIterator()
	while iter.%GetNext(.key, .entry)
	{
		if (entry.name = name)
		{
			set count = count + 1
		}
	} // while
	
	quit count
}

/// Return array item with the specified name.
/// In case of multiple items with the same name:
///   <var>entryNum</var> is the # of the item to be returned.
/// This method is intended to be used with "parameter" array of Parameters resource.
ClassMethod getArrayItemByName(array As %DynamicArray, name As %String, entryNum As %Integer = 1) As %DynamicObject
{
	#dim entry As %DynamicObject
	#dim iter As %Iterator.Object = array.%GetIterator()
	#dim count As %Integer = 0
	while iter.%GetNext(.key, .entry)
	{
		if (entry.name = name)
		{
			set count = count + 1
			if (entryNum = count) return entry
		}
	} // while
	
	quit ""
}

/// Return value[x] from the array item with the specified name.
/// Returned value can be either %String or %Boolean or %DynamicObject.
/// In case of multiple items with the same name:
///   <var>entryNum</var> is the # of the item to be returned.
/// This method is intended to be used with "parameter" and "parameter.part" arrays of Parameters resource.
ClassMethod getValueFromArrayItemByName(array As %DynamicArray, name As %String, entryNum As %Integer = 1) As %DynamicObject
{
	#dim entry As %DynamicObject
	#dim iter As %Iterator.Object = array.%GetIterator()
	#dim count As %Integer = 0
	while iter.%GetNext(.key, .entry)
	{
		if (entry.name = name)
		{
			set count = count + 1
			if (entryNum > count) continue
			if (entryNum < count) quit
			
			#dim iter2 As %Iterator.Object = entry.%GetIterator()
			#dim elVal As %DynamicObject = ""  // might be %String OR %Boolean OR %DynamicObject
			while iter2.%GetNext(.elName, .elVal)
			{
				if ((elName [ "value") && ($piece(elName, "value", 1) = ""))
				{
					return elVal
				}
			}
		}
	} // while
	
	quit ""
}

}

