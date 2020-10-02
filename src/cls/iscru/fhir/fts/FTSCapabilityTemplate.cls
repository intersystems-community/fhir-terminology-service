Class iscru.fhir.fts.FTSCapabilityTemplate Extends HS.FHIRServer.Tools.CapabilityTemplate
{

/// Overridden in order to amend the Capability Statement as per <var>pConfigObj</var>:
///  if _revinclude is not supported for a resource (i.e. resourceOverrides containing "searchRevInclude":[]),
///      then remove searchRevInclude array for that resource from the Capability Statement.
ClassMethod buildRestEntry(schema As HS.FHIRServer.Schema, pConfigObj As %DynamicObject)
{
	// call method of the superclass
	#dim rest As %DynamicObject = ##super(schema, pConfigObj)
	if '$isObject(rest) quit rest
	
	// collect resources that do not support _revinclude as per pConfigObj argument (i.e. resourceOverrides containing "searchRevInclude":[])
	kill rsrc
	#dim iter As %Iterator.Object = pConfigObj.resourceOverrides.%GetIterator()
	#dim name As %String
	#dim item As %DynamicObject
	while iter.%GetNext(.name, .item)
	{
		if (item.searchRevInclude '= "") && (item.searchRevInclude.%Size() = 0)
		{
			set rsrc(name) = 1
		}
	}

	// loop through resources in the Capability Statement 
	//    remove "searchRevInclude" array from resources that do not support _revinclude
	#dim restItem As %DynamicObject
	set iter = rest.resource.%GetIterator()
	while iter.%GetNext(.temp, .restItem)
	{
		if $data(rsrc(restItem.type))
		{
			do restItem.%Remove("searchRevInclude")
		}
	}

	quit rest
}

/// Overridden in order to amend the Capability Statement as per <var>pConfigObj</var>:
/// 1) add "profile" elements to resources (see "profile" elements in the XData block below),
/// 2) add "definition" elements to search parameters,
/// 3) add "operation" elements to resources (see "operations" elements in the XData block below).
/// Example of a "searchParams" element within "resourceOverrides" element of pConfigObj:
/// 			"searchParams": [{
/// 					"name": "url",
/// 					"definition": "urn:SearchParameter:valueset-url"
/// 			}]
ClassMethod buildResourceEntry(schema As HS.FHIRServer.Schema, pType As %String, pConfigObj As %DynamicObject) As %DynamicObject
{
	// call method of the superclass
	#dim rsrc As %DynamicObject = ##super(schema, pType, pConfigObj)
	if '$isObject(rsrc) quit rsrc
	
	///////////// 1) add profile element to resource
	#dim profile As %String = ..getValue(rsrc.type, "profile", pConfigObj)
	if (profile '= "") do rsrc.%Set("profile", profile)
	
	///////////// 2) add definition elements to search parameters
	
	// get additional info for search parameters from pConfigObj
	#dim spDefinitionsArray As %DynamicArray = ..getValue(rsrc.type, "searchParams", pConfigObj)
	
	if $isObject(spDefinitionsArray) 
			&& spDefinitionsArray.%Extends("%DynamicArray") 
			&& (spDefinitionsArray.%Size() > 0)
			&& (rsrc.%GetTypeOf("searchParam") = "array") 
			&& (rsrc.searchParam.%Size() > 0)
	{
		// loop through spDefinitionsArray and cache definitions into a local associative array
		// assumption: each spDefinitionsArray element has "name" and "definition" fields
		kill spDefs
		#dim iter As %Iterator.Array = spDefinitionsArray.%GetIterator()
		#dim key As %String
		#dim val As %DynamicObject
		while iter.%GetNext(.key, .val)
		{
			if $isObject(val) && val.%Extends("%DynamicObject") && (val.%Get("name") '= "")
			{
				set spDefs(val.%Get("name")) = val.%Get("definition")
			}
		}
		
		set iter = rsrc.%Get("searchParam").%GetIterator()
		while iter.%GetNext(.key, .val)
		{
		if $isObject(val) && val.%Extends("%DynamicObject")
			{
				#dim name As %String = val.%Get("name")
				#dim definition As %String = ""
				if (name '= "") && $data(spDefs(name), definition)
				{
					do val.%Set("definition", definition)
				}
			}
		}
	}
	
	///////////// 3) add operation elements to resources
	
	// get operations info from pConfigObj
	#dim operationsArray As %DynamicArray = ..getValue(rsrc.type, "operations", pConfigObj)
	
	if $isObject(operationsArray) && operationsArray.%Extends("%DynamicArray") && (operationsArray.%Size() > 0)
	{
		#dim operIter As %Iterator.Array = operationsArray.%GetIterator()
		#dim operKey As %String
		#dim operVal As %DynamicObject
		while operIter.%GetNext(.operKey, .operVal)
		{
			if $isObject(operVal) && operVal.%Extends("%DynamicObject") && (operVal.%Get("name") '= "")
			{
				if (rsrc.%Get("operation") = "") set rsrc.operation = $$$NewJSONArray
				
				#dim oper As %DynamicObject = $$$NewJSONObject
				set oper.name = operVal.%Get("name")
				set oper.definition = operVal.%Get("definition")
				
				do rsrc.operation.%Push(oper)
			}
		}
	}
	
	quit rsrc
}

/// Returns paramExclude array from ConfigFull xdata block
ClassMethod getExcludedSearchParams() As %DynamicArray
{
	#dim config As %DynamicObject = ##class(iscru.fhir.JSONUtils).getJsonFromXdata($classname(), "ConfigFull")
	quit config.paramExclude
}

/// Overridden in order to amend the Capability Statement in regard to CodeSystem and ValueSet resources:
///  1) remove unsupported search parameters;
///  2) limit supported interactions to read and search-type;
///  3) "versioning": "no-version";
///  4) _include/_revinclude parameters not supported;
///  5) add profile urls;
///  6) add resource level operations (note that $validate-code is defined for both ValueSet and CodeSystem resources).
/// 
/// (Fields suffixed with "-Documentation" explain how that setting changes the capabilities.)
XData ConfigFull [ MimeType = application/json ]
{
{
	"general-Documentation": [
		"This object controls the generation of a Metadata resource"
	],
	
	"paramExclude-Documentation": [
		"Each Entry represents a search parameter in the form of:"
		, "   <ResourceType>.<paramName> "
		, "that we do NOT want to support in the generated Metadata resource."
		, ""
		, "sort, offset, count and filter params of ValueSet resource correspond to input parameters of $expand operation, "
		, " i.e. not real search parameters, hence we need to exclude them;" 
		, " those parameters have been added to metadata set due to IF-1233 issue"
		, ""
		, " same problem with system and display input parameters of $validate-code operation which is defined for both ValueSet and CodeSystem"
		, ""
		, " url is the only search parameter currently supported for ValueSet and CodeSystem resources (see TerminologyInteractions class),"
		, " hence excluding all other search parameters for ValueSet and CodeSystem"
	],

	"paramExclude": [
		"Resource._content",
		"Resource._query",
		
		"ValueSet.code",
		"ValueSet.context",
		"ValueSet.context-quantity",
		"ValueSet.context-type",
		"ValueSet.context-type-quantity",
		"ValueSet.context-type-value",
		"ValueSet.date",
		"ValueSet.description",
		"ValueSet.expansion",
		"ValueSet.experimental",
		"ValueSet.identifier",
		"ValueSet.jurisdiction",
		"ValueSet.name",
		"ValueSet.publisher",
		"ValueSet.reference",
		"ValueSet.status",
		"ValueSet.title",
		"ValueSet.version",

		"ValueSet.sort",
		"ValueSet.offset",
		"ValueSet.count",
		"ValueSet.filter",
		
		"ValueSet.system",
		"ValueSet.display",
		
		"CodeSystem.code",
		"CodeSystem.content-mode",
		"CodeSystem.context",
		"CodeSystem.context-quantity",
		"CodeSystem.context-type",
		"CodeSystem.context-type-quantity",
		"CodeSystem.context-type-value",
		"CodeSystem.date",
		"CodeSystem.description",
		"CodeSystem.identifier",
		"CodeSystem.jurisdiction",
		"CodeSystem.language",
		"CodeSystem.name",
		"CodeSystem.publisher",
		"CodeSystem.status",
		"CodeSystem.supplements",
		"CodeSystem.title",
		"CodeSystem.version",
		
		"CodeSystem.display"
	],
	
	"resourceDefaults-Documentation": [
		"These are the default values to apply to each resource added to the",
		"Metadata resource."
	],
	
	"resourceDefaults": {
		"interactions": [
			"read",
			"vread",
			"create",
			"update",
			"delete",
			"history-instance",
			"search-type"
		],
		"versioning": "versioned",
		"readHistory": false,
		"updateCreate": true,
		"conditionalCreate": true,
		"conditionalRead": "not-supported",
		"conditionalUpdate": true,
		"conditionalDelete": "not-supported"
	},
	
	"resourceOverrides-Documentation": [
		"Add an object with a resource name as a key.  Properties of the object",
		"will override the default value for all resources.  The first use is",
		"an override to the CapabilityStatement resource to indicate that only READ is allowed",
		"",
		"read and search-type are the only interactions currently supported for ValueSet and CodeSystem resources"
	],
	
	"resourceOverrides": {
		"CapabilityStatement": {
			"interactions": [
				"read"
			]
		},
		"Resource": {
			"interactions": [
				"transaction"
			]
		},
		
		"ValueSet": {
			"profile": "urn:StructureDefinition:objectscript-valueset",
			"searchRevInclude": [],
			"versioning": "no-version",
			"interactions": [
				"read",
				"search-type"
			],
			"operations": [
				{"name": "expand", "definition": "urn:OperationDefinition:ValueSet-expand"},
				{"name": "validate-code", "definition": "urn:OperationDefinition:ValueSet-validate-code"}
			]
		},
		
		"CodeSystem": {
			"profile": "urn:StructureDefinition:objectscript-codesystem",
			"searchRevInclude": [],
			"versioning": "no-version",
			"interactions": [
				"read",
				"search-type"
			],
			"operations": [
				{"name": "lookup", "definition": "urn:OperationDefinition:CodeSystem-lookup"},
				{"name": "validate-code", "definition": "urn:OperationDefinition:CodeSystem-validate-code"}
			]
		}
	},
	
	"resourceList-Documentation": [
		"If present, this is the inclusive list of Resources to be supported by this",
		"Metadata object.  If not present, all resources in the schema are included"
	],
	"resourceListX": [
		"Patient", "Encounter"
	]
}
}

/* //within resource within "resourceOverrides" - custom search param:
			"searchParams": [
				{
					"name": "url",
					"definition": "urn:SearchParameter:valueset-url"
				}
			]
*/
/// COPIED AS-IS FROM HS.FHIRServer.Tools.CapabilityTemplate
/// Descriptive fields. None of these fields will modify functionality of an endpoint
XData BaseResource [ MimeType = application/json ]
{
{
  "resourceType": "CapabilityStatement",
  "id": "InterSystemsFHIRServer",
  "meta": {
    "versionId": "1",
    "lastUpdated": "2019-01-15T00:00:00Z"
  },
  "url": "<replaced at runtime>",
  "version": "1",
  "name": "InterSystems FHIR Server CapabilityStatement",
  "status": "active",
  "experimental": false,
  "date": "2020-01-15",
  "publisher": "InterSystems Corporation",
  "kind": "instance",
  "software": {
    "name": "InterSystems FHIR Server",
    "version": "2020.1"
  },
  "implementation": {
    "description": "InterSystems FHIR Server",
    "url": "<replaced at runtime>"
  },
  "fhirVersion": "<replaced by builder>",
  "acceptUnknown": "no",
  "format": [
    "xml",
    "json"
  ],
  "rest": [
  ]
}
}

}

