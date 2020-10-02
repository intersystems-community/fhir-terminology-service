/// Partial implementation of FHIR Terminology Service (https://www.hl7.org/fhir/R4/terminology-service.html)
/// that exposes persistent classes as CodeSystem/ValueSet resources.
Class iscru.fhir.fts.FTSStrategy Extends HS.FHIRServer.Storage.Json.InteractionsStrategy [ Abstract ]
{

/// To be overridden in subclasses.
Parameter StrategyKey As %String;

Parameter InteractionsClass As %String = "iscru.fhir.fts.FTSInteractions";

/// Canonical id prefix for all ValueSets.
/// (ValueSet.url = Canonical identifier for a value set, represented as a URI, globally unique)
Parameter valueSetUrlPREFIX = "urn:ValueSet:";

/// Canonical id prefix for all CodeSystems.
/// (CodeSystem.url = Canonical identifier for a code system, represented as a URI, globally unique)
Parameter codeSystemUrlPREFIX = "urn:CodeSystem:";

/// Returns a list ($lb) of all available code table classes.
/// To be implemented in subclasses.
/// Return an empty string to disallow search requests without "url" search param specified.
ClassMethod listCodeTableClasses() As %List
{
	quit ""
}

/// Returns package name for a given code table.
/// To be implemented in subclasses.
ClassMethod getCodeTablePackage(shortClassName As %String, resourceType As %String, url As %String) As %String [ Abstract ]
{
}

/// Returns name of class property which maps to CodeSystem.concept.code element.
/// To be implemented in subclasses.
ClassMethod getCodePropertyName(className As %String) As %String [ Abstract ]
{
}

/// Returns name of class property which maps to CodeSystem.concept.display element.
/// To be implemented in subclasses.
ClassMethod getDisplayPropertyName(className As %String) As %String [ Abstract ]
{
}

/// This method indicates whether a code table property should be excluded from CodeSystem's property list.
/// Might be overridden in subclasses.
ClassMethod isExcludedProperty(className As %String, propertyName As %String) As %Boolean
{
	// exclude properties: Collection, Internal, MultiDimensional, Private, Identity
	if ("" '= $$$comMemberKeyGet(className, $$$cCLASSproperty, propertyName, $$$cPROPcollection)) quit $$$YES
	if $$$comMemberKeyGet(className, $$$cCLASSproperty, propertyName, $$$cPROPinternal) quit $$$YES
	if $$$comMemberKeyGet(className, $$$cCLASSproperty, propertyName, $$$cPROPmultidimensional) quit $$$YES
	if $$$comMemberKeyGet(className, $$$cCLASSproperty, propertyName, $$$cPROPprivate) quit $$$YES
	if $$$comMemberKeyGet(className, $$$cCLASSproperty, propertyName, $$$cPROPidentity) quit $$$YES

	quit $$$NO
}

/// @API<br>
/// Return a CapabilityStatement metadata resource. The returned content is derived from
/// a strategy-specific means of formulating a CapabilityStatement. An example use of the
/// output might be to store the CapabilityStatement for a given Service.<br>
/// This method should not be confused with the Interactions class LoadMetadata() method,
/// which retrieves the stored CapabilityStatement for the current Service.
Method GetMetadataResource() As %DynamicObject
{
	// custom CapabilityTemplate
	return ##class(iscru.fhir.fts.FTSCapabilityTemplate).BuildFull(..InstanceKey)
}

/// Determine code table class name (and sql name) given ValueSet.url or CodeSystem.url.
ClassMethod determineCodeTableClassname(resourceType As %String, url As %String, Output sqlTableName As %String) As %String
{
	set sqlTableName = ""
	#dim prefix As %String = ""
	
	if (resourceType = "ValueSet") set prefix = $select(url [ ..#valueSetUrlPREFIX:..#valueSetUrlPREFIX, 1:"")
	if (resourceType = "CodeSystem") set prefix = $select(url [ ..#codeSystemUrlPREFIX:..#codeSystemUrlPREFIX, 1:"")
	if (prefix = "") quit ""
	
	#dim len As %Integer = $length(prefix)
	if ($extract(url, 1, len) '= prefix) quit ""
	
	#dim shortName As %String = $extract(url, len + 1, *)
	#dim return As %String = ..getCodeTablePackage(shortName, resourceType, url) _ "." _ shortName
	
	set sqlTableName = $$quoter2^%apiSQL($$$comClassKeyGet(return, $$$cCLASSsqlschemaname)) _ "." _ $$quoter2^%apiSQL($$$comClassKeyGet(return, $$$cCLASSsqltablename))
	if (sqlTableName = ".") set sqlTableName = ""
	
	quit return
}

ClassMethod getValueSetForClassname(className As %String) As %String
{
	#dim shortClassName As %String = $piece(className, ".", *)
	#dim url As %String = ..#valueSetUrlPREFIX _ shortClassName
	#dim packageName As %String = ..getCodeTablePackage(shortClassName, "ValueSet", url)
	
	if (packageName '= $piece(className, ".", 1, *-1))
	{
		quit ""
	}
	else
	{
		quit url
	}
}

ClassMethod getCodeSystemForClassname(className As %String) As %String
{
	#dim shortClassName As %String = $piece(className, ".", *)
	#dim url As %String = ..#codeSystemUrlPREFIX _ shortClassName
	#dim packageName As %String = ..getCodeTablePackage(shortClassName, "CodeSystem", url)
	
	if (packageName '= $piece(className, ".", 1, *-1))
	{
		quit ""
	}
	else
	{
		quit url
	}
}

/// Determine CodeSystem.url given ValueSet.url
ClassMethod determineCodeSystemForValueSet(valueSetURL As %String) As %String
{
	#dim shortName As %String = $extract(valueSetURL, $length(..#valueSetUrlPREFIX) + 1, *)
	quit ..#codeSystemUrlPREFIX _ shortName
}

/// Collect properties of a code table class to an associative array indexed by $$$cPROPsequencenumber, with root node equal to property count:
///   result = [property count]
///   result(n, "name") = [property name]
///   result(n, "description") = [property description]
///   result(n, "fhirDataType") = [FHIR datatype of the property]
///   result(n, "clientDataType") = [property's ClientDataType]
///   result(n, "valueElementName") = [one of the following: valueCode | valueCoding | valueString | valueInteger | valueBoolean | valueDateTime | valueDecimal]
/// This method calls isExcludedProperty() to check whether a particular property should be excluded from result.
/// Properties listed in <var>excludeList</var> are always excluded.
/// TODO: currently non-datatype properties are excluded.
ClassMethod getCodeTableProperties(className As %String, excludeList As %List, Output result)
{
	kill result
	set result = 0
	
	#dim property As %String = ""
	for
	{
		set property = $$$comMemberNext(className, $$$cCLASSproperty, property)
		if (property = "") quit
		
		// skip properties from excludeList
		if ($listfind(excludeList, property) > 0) continue
		
		// skip properties: Collection, Internal, MultiDimensional, Private, Identity and maybe others - depending on subclass implementation
		if ..isExcludedProperty(className, property) continue
		
		#dim propType As %String = $$$comMemberKeyGet(className, $$$cCLASSproperty, property, $$$cPROPtype)
		#dim propClsType As %String = $$$getClassType(propType)
		
		// TODO: support object properties - references to code tables
		if (propClsType '= "datatype") continue // skip non-datatype properties
		
		#dim clientDataType As %String = $$$comClassKeyGet(propType, $$$cCLASSclientdatatype)
		
		// https://www.hl7.org/fhir/R4/valueset-concept-property-type.html
		// code | Coding | string | integer | boolean | dateTime | decimal
		#dim fhirDataType As %String = $case(clientDataType, "BOOLEAN":"boolean", "INTEGER":"integer", "NUMERIC":"decimal", "DECIMAL":"decimal", "FLOAT":"decimal", "TIMESTAMP":"dateTime", "DATE":"dateTime", :"string")

		// valueCode | valueCoding | valueString | valueInteger | valueBoolean | valueDateTime | valueDecimal
		#dim valueElementName As %String = "value" _ $zcvt($extract(fhirDataType, 1), "U") _ $extract(fhirDataType, 2, *)
		
		#dim position As %Integer = +$$$comMemberKeyGet(className, $$$cCLASSproperty, property, $$$cPROPsequencenumber)
		set result(position, "name") = property
		set result(position, "description") = $$$comMemberKeyGet(className, $$$cCLASSproperty, property, $$$cPROPdescription)
		set result(position, "fhirDataType") = fhirDataType
		set result(position, "clientDataType") = clientDataType
		set result(position, "valueElementName") = valueElementName
		set result = 1 + $get(result)
	}
}

/* Commented the following methods out due to IF-1233 issue which was the reason for adding dummy search parameters 
  that correspond to input parameters of $expand: sort, offset, count and filter, and to input parameters of $validate-code: system and display.
Those fake search parameters need to remain supported while they are excluded from the CapabilityStatement resource (/metadata response) - see the custom CapabilityTemplate class.

/// Overridden in order to remove unsupported search parameters from schema
Method %OnNew(serviceInstance As HS.FHIRServer.ServiceInstance) As %Status
{
	// %OnNew() method of HS.FHIRServer.API.InteractionsStrategy calls Schema.LoadSchema() method that creates Schema instance and sets it up using $$$FSMetaGlobal data
	#dim sc As %Status = ##super(serviceInstance)
	if $$$ISERR(sc) quit sc
	
	// remove unsupported search parameters from schema
	do ..removeUnsupportedSearchParams(..%schema)
	
	quit $$$OK
}

/// This method removes unsupported search params from schema.
/// If this method is not called, then all search params in the metadata set are treated as supported - regardless of the Capability Statement!
/// 
/// NOTE: By default FHIR endpoint is configured with DefaultPreferHandling=lenient, making the server ignore unsupported search params when processing a search request.
/// Configure it with DefaultPreferHandling=strict to throw an error for a search request containing unsupported search param(s).
/// 
/// NOTE2: If ALL search params for a given resource are removed, then the resource won't show up in the Capability Statement at all, and its search table class won't be generated.
/// 
/// NOTE3: If a search param needs to become supported after being unsupported, then resource's search table class has to be rebuit and re-populated.
/// 
ClassMethod removeUnsupportedSearchParams(schema As HS.FHIRServer.Schema) [ Private ]
{
	// get the list of unsupported search params from ConfigFull XData of iscru.fhir.fts.FTSCapabilityTemplate class
	#dim excludedSearchParams As %DynamicArray = ##class(iscru.fhir.fts.FTSCapabilityTemplate).getExcludedSearchParams()
	if (excludedSearchParams = "") quit

	// cache unsupported search params to a multidim array: excluded(resource, param)=1
	kill excluded
	#dim iter As %Iterator.Array = excludedSearchParams.%GetIterator()
	#dim item As %String
	while iter.%GetNext(.temp, .item)
	{
		set excluded($piece(item, ".", 1), $piece(item, ".", 2)) = 1
	}
	
	// remove unsupported search params from schema
	#dim resource As %String = ""
	for
	{
		set resource = $order(schema.searchParams(resource))
		if (resource = "") quit
		
		if '$data(excluded(resource)) continue
		
		#dim sp As %String = ""
		for
		{
			set sp = $order(schema.searchParams(resource, sp))
			if (sp = "") quit
			
			if $data(excluded(resource, sp)) 
			{
				kill schema.searchParams(resource, sp)
			}
		}
	}
}
*/
}

