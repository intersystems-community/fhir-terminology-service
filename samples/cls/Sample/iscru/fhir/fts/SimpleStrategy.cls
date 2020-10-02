/// Sample Strategy class for a simple terminology service with *all* code table classes 
/// belonging to the same package and containing "code" and "description" properties.
Class Sample.iscru.fhir.fts.SimpleStrategy Extends iscru.fhir.fts.FTSStrategy
{

Parameter StrategyKey As %String = "Sample.iscru.fhir.fts.SimpleStrategy";

/// Code tables package
Parameter codeTablePACKAGE = "Sample.iscru.fhir.fts.model";

ClassMethod getCodeTablePackage(shortClassName As %String, resourceType As %String, url As %String) As %String
{
	quit ..#codeTablePACKAGE
}

/// Returns name of class property which maps to CodeSystem.concept.code element.
ClassMethod getCodePropertyName(className As %String) As %String
{
	quit "code"
}

/// Returns name of class property which maps to CodeSystem.concept.display element.
ClassMethod getDisplayPropertyName(className As %String) As %String
{
	quit "description"
}

/// Returns a list of all available code table classes.
ClassMethod listCodeTableClasses() As %List
{
	#dim sql As %String = "SELECT name FROM %Dictionary.ClassDefinition WHERE name LIKE '" _ ..#codeTablePACKAGE _ ".%' ORDER BY name"
	#dim resultSet As %SQL.StatementResult = ##class(%SQL.Statement).%ExecDirect(, sql)
	if (resultSet.%SQLCODE '= 0) && (resultSet.%SQLCODE '= 100) $$$ThrowStatus($$$ERROR($$$SQLError, resultSet.%SQLCODE, resultSet.%Message))

	#dim return As %List = ""
	while resultSet.%Next()
	{
		set return = return _ $lb(resultSet.name)
	}
	
	quit return
}

}

