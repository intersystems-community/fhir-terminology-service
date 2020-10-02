Class iscru.fhir.fts.FTSOperations Extends (HS.FHIRServer.Storage.BuiltInOperations, iscru.fhir.fts.ExpandOperation, iscru.fhir.fts.LookupOperation, iscru.fhir.fts.ValidateCodeOperation)
{

/// @API Enumerate the name and url of each Operation supported by this class
ClassMethod AddSupportedOperations(pMap As %DynamicObject)
{
	do ##class(HS.FHIRServer.Storage.BuiltInOperations).AddSupportedOperations(pMap)
	
	/* Custom CapabilityTemplate class adds all resource level operations to the Capability Statement!
	Hence no need to add operations at the system level.
	
	// add custom operations: $lookup and $expand
	do ##class(iscru.fhir.fts.ExpandOperation).AddSupportedOperations(pMap)
	do ##class(iscru.fhir.fts.LookupOperation).AddSupportedOperations(pMap)
	do ##class(iscru.fhir.fts.ValidateCodeOperation).AddSupportedOperations(pMap)
	*/
}

}

