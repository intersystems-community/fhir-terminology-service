/// Sample code table class
Class Sample.iscru.fhir.fts.model.CodeTable Extends (%Persistent, %Populate)
{

/// code
Property code As %String(MAXLEN = 50);

/// display
Property description As %String(MAXLEN = "", POPSPEC = "Mission()");

Property testBoolean As %Boolean;

Property testDate As %Date;

Property testTS As %TimeStamp;

Property testDecimal As %Decimal(SCALE = 4);

Index codeIndex On code [ IdKey, PrimaryKey, Unique ];

Method OnPopulate() As %Status
{
	#dim rs As %ResultSet = ##class(%ResultSet).%New($classname() _ ":Extent")
	$$$ThrowOnError(rs.Execute())

	// if this is the first row then assign "TEST" to code
	if 'rs.Next() set ..code = "TEST"
	
	quit $$$OK
}

Storage Default
{
<Data name="CodeTableDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>description</Value>
</Value>
<Value name="3">
<Value>testBoolean</Value>
</Value>
<Value name="4">
<Value>testDate</Value>
</Value>
<Value name="5">
<Value>testTS</Value>
</Value>
<Value name="6">
<Value>testDecimal</Value>
</Value>
</Data>
<DataLocation>^Sample.iscru.fhi89A0.CodeTableD</DataLocation>
<DefaultData>CodeTableDefaultData</DefaultData>
<ExtentSize>10</ExtentSize>
<IdLocation>^Sample.iscru.fhi89A0.CodeTableD</IdLocation>
<IndexLocation>^Sample.iscru.fhi89A0.CodeTableI</IndexLocation>
<Property name="%%CLASSNAME">
<AverageFieldSize>1</AverageFieldSize>
<Selectivity>100.0000%</Selectivity>
</Property>
<Property name="%%ID">
<AverageFieldSize>4.8</AverageFieldSize>
<Selectivity>1</Selectivity>
</Property>
<Property name="code">
<AverageFieldSize>4.8</AverageFieldSize>
<Selectivity>1</Selectivity>
</Property>
<Property name="description">
<AverageFieldSize>1</AverageFieldSize>
<Selectivity>10.0000%</Selectivity>
</Property>
<Property name="testBoolean">
<AverageFieldSize>1</AverageFieldSize>
<Selectivity>50.0000%</Selectivity>
</Property>
<Property name="testDate">
<AverageFieldSize>5</AverageFieldSize>
<Selectivity>10.0000%</Selectivity>
</Property>
<Property name="testDecimal">
<AverageFieldSize>8.9</AverageFieldSize>
<Selectivity>10.0000%</Selectivity>
</Property>
<Property name="testTS">
<AverageFieldSize>19</AverageFieldSize>
<Selectivity>10.0000%</Selectivity>
</Property>
<SQLMap name="codeIndex">
<BlockCount>-4</BlockCount>
</SQLMap>
<StreamLocation>^Sample.iscru.fhi89A0.CodeTableS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}

