/// Container class for JSON utility methods, parameters etc.
Class iscru.fhir.JSONUtils [ Abstract ]
{

/// Get %DynamicObject from the specified XData block with MimeType=application/json
ClassMethod getJsonFromXdata(className As %String, xdata As %String) As %DynamicObject
{
	#dim stream As %Stream.TmpCharacter = ##class(%Stream.TmpCharacter).%New()
	
	for i = 1:1:$$$comMemberKeyGet(className, $$$cCLASSxdata, xdata, $$$cXDATAdata)
	{
		do stream.WriteLine($$$comMemberArrayGet(className, $$$cCLASSxdata, xdata, $$$cXDATAdata, i))
	}

	quit ##class(%DynamicObject).%FromJSON(stream)
}

/// Debugging utility method: serialize an arbitrary object to a JSON stream.
ClassMethod obj2json(obj As %RegisteredObject) As %Stream.Object
{
	#dim stream As %FileCharacterStream = ##class(%FileCharacterStream).%New()
	set stream.TranslateTable = "UTF8"
	
	do stream.Write("")
	
	#dim file As %String = stream.Filename
	
	// запоминаем текущий девайс
	#dim oldIO = $io
	#dim oldMnemonic As %String = ##class(%Device).GetMnemonicRoutine()
	#dim oldIORedirected As %Boolean = ##class(%Device).ReDirectIO()
	#dim sc As %Status = $$$OK
	
	use file:(/NOXY)
	try
	{
		set sc = ##class(%ZEN.Auxiliary.altJSONProvider).%ObjectToJSON(obj,,,"aeloq")
	}
	catch ex
	{
		set sc = $get(%objlasterror)
		if (sc = "") set sc = ex.AsStatus()
	}
	close file
	
	if (oldMnemonic '= "")
	{
		use oldIO::("^"_oldMnemonic)
	}
	else 
	{
		use oldIO
	}
	do ##class(%Device).ReDirectIO(oldIORedirected)
	
	$$$ThrowOnError(sc)
	
	do stream.Rewind()
	quit stream
}

}

