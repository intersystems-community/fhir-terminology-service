# fhir-terminology-service
Implementation of FHIR Terminology Service specification (https://www.hl7.org/fhir/R4/terminology-service.html) to expose arbitrary persistent classes as FHIR value sets and code systems. Runs on InterSystems IRIS for Health 2020+.

## Installation
0. Clone/git pull the repo into any local directory, e.g.:
```
$ git clone https://github.com/intersystems-ru/fhir-terminology-service.git
```
1. Install IRIS for Health 2020.1 or newer.
2. Create "terminology" directory in <installation directory>/dev/fhir/fhir-metadata, and copy [dummy-search-parameters.json](../main/src/fhir-search-parameters/dummy-search-parameters.json) file there. The file contains dummy search parameters for ValueSet and CodeSystems resources. Those parameters are required in order for $expand and $validate-code operations to work via HTTP GET.
3. Open IRIS terminal and set up a new "foundation" namespace, e.g.:
```
USER> zn "HSLIB"
HSLIB> do ##class(HS.HC.Util.Installer).InstallFoundation("terminology")
```
4.Import classes into the namespace, e.g.:
```
HSLIB> zn "terminology"
TERMINOLOGY> do $System.OBJ.ImportDir("/tmp/fhir-terminology-service/src/cls/", "*.cls", "ckbud", .err, 1)
```
5. Create custom strategy class - a subclass of [iscru.fhir.fts.FTSStrategy](../main/src/cls/iscru/fhir/fts/FTSStrategy.cls). Override StrategyKey parameter as well as getCodeTablePackage(), getCodePropertyName() and getDisplayPropertyName() methods, e.g.:
```
Parameter StrategyKey = "<full name of the new class>";

ClassMethod getCodeTablePackage(shortClassName As %String, resourceType As %String, url As %String) As %String
{
	quit "<name of the package that all code table classes belong to>"
}

ClassMethod getCodePropertyName(className As %String) As %String
{
	quit "<name of the 'code' property, i.e. the property that will be mapped to CodeSystem.concept.code element>"
}

ClassMethod getDisplayPropertyName(className As %String) As %String
{
	quit "<name of the 'display' property, i.e. the property that will be mapped to CodeSystem.concept.display element>"
}
```
* Refer to [Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/src/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls) as an example of a custom strategy class.
* Implement listCodeTableClasses() method to enable searching CodeSystem/ValueSet resources without specifying url.
* Override isExcludedProperty() method if any properties of code table classes should not be included into the corresponding CodeSystem resources.

6. Run ```do ##class(HS.FHIRServer.ConsoleSetup).Setup()``` and create a custom metadata set with dummy search parameters for CodeSystem and ValueSet resources:
```
TERMINOLOGY>do ##class(HS.FHIRServer.ConsoleSetup).Setup()
What do you want to do?
  0)  Quit
  1)  Create a FHIRServer Endpoint
  2)  Display a FHIRServer Endpoint Configuration
  3)  Configure a FHIRServer Endpoint
  4)  Delete a FHIRServer Endpoint
  5)  Update the CapabilityStatement Resource
  6)  Migrate Data from pre-2020.1
  7)  Re-index FHIRServer Storage
  8)  Create a custom metadata set
  9)  Update a custom metadata set
  10) Delete a custom metadata set
Choose your Option[1] (0-10): 8
 
Choose a base FHIR Metadata Configuration to extend
  1) HL7v30 (Base HL7 Metadata for FHIR STU3 (3.0.1))
  2) HL7v40 (Base HL7 Metadata for FHIR R4 (4.0.1))
Choose the Metadata Set[1] (1-2): 2
Enter a name for the metadata set without spaces or punctuation[-]: HL7v40terminology
Enter a description for the metadata set[-]: FHIR R4 metadata plus dummy search parameters
Enter a directory which contains the custom metadata[-]: C:\InterSystems\IRISHealth20202\dev\fhir\fhir-metadata\terminology
You are about to create metadata set 'HL7v40terminology'. Proceed?[no] (y/n): yes
...
```
7. Create a new FHIR endpoint based on the new metadata set and your custom strategy class ([Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/src/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls) is shown below as a custom strategy class):
```
What do you want to do?
  0)  Quit
  1)  Create a FHIRServer Endpoint
  2)  Display a FHIRServer Endpoint Configuration
  3)  Configure a FHIRServer Endpoint
  4)  Delete a FHIRServer Endpoint
  5)  Update the CapabilityStatement Resource
  6)  Migrate Data from pre-2020.1
  7)  Re-index FHIRServer Storage
  8)  Create a custom metadata set
  9)  Update a custom metadata set
  10) Delete a custom metadata set
Choose your Option[8] (0-10): 1
  1) Json (All Resources stored in a single table as Json text)
  2) Sample.iscru.fhir.fts.SimpleStrategy (All Resources stored in a single table as Json text)
Choose the Storage Strategy[1] (1-2): 2
 
Choose the FHIR Metadata Configuration
  1) HL7v30 (Base HL7 Metadata for FHIR STU3 (3.0.1))
  2) HL7v40 (Base HL7 Metadata for FHIR R4 (4.0.1))
  3) HL7v40terminology (FHIR R4 metadata plus dummy search parameters)
Choose the Metadata Set[1] (1-3): 3
Do you want to create the default repository endpoint, /csp/healthshare/terminology/fhir/r4? (y/n): yes
Enter the OAuth Client Name for this Endpoint (if any)[-]:
You are about to create a HL7v40terminology endpoint at /csp/healthshare/terminology/fhir/r4.  Proceed?[no] (y/n): yes
...
```
8. Next, configure the endpoint - just change DebugMode to 4 leaving default values for everything else:
```
What do you want to do?
  0)  Quit
  1)  Create a FHIRServer Endpoint
  2)  Display a FHIRServer Endpoint Configuration
  3)  Configure a FHIRServer Endpoint
  4)  Delete a FHIRServer Endpoint
  5)  Update the CapabilityStatement Resource
  6)  Migrate Data from pre-2020.1
  7)  Re-index FHIRServer Storage
  8)  Create a custom metadata set
  9)  Update a custom metadata set
  10) Delete a custom metadata set
Choose your Option[1] (0-10): 3
 
Which Endpoint do you want to configure?
  1) /csp/healthshare/terminology/fhir/r4 [enabled] (for Strategy 'Sample.iscru.fhir.fts.SimpleStrategy' and Metadata Set 'HL7v40terminology')
Choose the Endpoint[1] (1-1): 1
Endpoint enabled[yes] (y/n): yes
 
-- Edit CSP Application Configuration --
OAuthClientName[-]:
ServiceConfigName[-]:
 
-- Edit FHIRService Configuration --
RequiredResource[-]:
FHIRSessionTimeout[300]: 300
DefaultSearchPageSize[100]: 100
MaxSearchPageSize[100]: 100
MaxSearchResults[1000]: 1000
MaxConditionalDeleteResults[3]: 3
DefaultPreferHandling[lenient]: lenient
DebugMode[0]: 4
            FHIRMetadataSet: HL7v40terminology
                FHIRVersion: 4.0.1
  InteractionsStrategyClass: Sample.iscru.fhir.fts.SimpleStrategy
           RequiredResource:
         FHIRSessionTimeout: 300
      DefaultSearchPageSize: 100
          MaxSearchPageSize: 100
           MaxSearchResults: 1000
MaxConditionalDeleteResults: 3
      DefaultPreferHandling: lenient
                  DebugMode: 4
Save Changes? (y/n): yes
Changes have been saved
```
9. Import [fhir-terminology-service.postman_collection.json](../main/tests/postman/fhir-terminology-service.postman_collection.json) file into Postman, adjust "url" variable defined for the collection, test the service against your code table classes (you'd need to modify request parameters accordingly).
There is the [Sample.iscru.fhir.fts.model.CodeTable](../main/samples/src/cls/Sample/iscru/fhir/fts/model/CodeTable.cls) sample class in the repo. If you import and populate it (```do ##class(Sample.iscru.fhir.fts.model.CodeTable).Populate(10)```), then the predefined requests from Postman collection can be tested right away.

## Supported FHIR Interactions
Currently read and search-type interactions for ValueSet and CodeSystem resources are supported. The only supported search parameter for both resources is "url".

Supported operations: CodeSystem/$lookup, CodeSystem/$validate-code, ValueSet/$expand and ValueSet/$validate-code.
Both HTTP GET and HTTP POST methods are supported for all the four operations.

Find below sample GET requests against Sample.iscru.fhir.fts.model.CodeTable code table class. Prepend each URI with ```http://<server>:<port><web app path>```.
| URI to be prepended with with ```http://<server>:<port><web app path>```   | Description                                                                           |
|----------------------------------------------------------------------------|---------------------------------------------------------------------------------------|
| /metadata                                                                  | Get endpoint's Capability Statement resource.                                         |
| /CodeSystem/Sample.iscru.fhir.fts.model.CodeTable                          | Read CodeSystem resource corresponding to Sample.iscru.fhir.fts.model.CodeTable class.|
| /ValueSet/Sample.iscru.fhir.fts.model.CodeTable                            | Read ValueSet resource corresponding to Sample.iscru.fhir.fts.model.CodeTable class.  |
| /CodeSystem?url=urn:CodeSystem:CodeTable                                   | Search CodeSystem resource by url.                                                    |
| /CodeSystem                                                                | Output all avaliable CodeSystem resources.                                            |
| /ValueSet?url=urn:ValueSet:CodeTable                                       | Search ValueSet resource by url.                                                      |
| /ValueSet                                                                  | Output all avaliable ValueSet resources.                                              |
| /CodeSystem/$lookup?system=urn:CodeSystem:CodeTable&code=TEST              | Given system and code, get all the details about the concept.                         |
| /ValueSet/$expand?url=urn:ValueSet:CodeTable                               | Expand the ValueSet.                                                                  |
| /CodeSystem/Sample.iscru.fhir.fts.model.CodeTable/$validate-code?code=TEST | Validate that a code is in the code system.                                           |
