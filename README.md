# fhir-terminology-service
Implementation of FHIR Terminology Service specification (https://www.hl7.org/fhir/R4/terminology-service.html) to expose arbitrary persistent classes as FHIR value sets and code systems. Runs on InterSystems IRIS for Health 2020+.

## Installation
0. Clone/git pull the repo into any local directory, e.g.:
	```
	$ git clone https://github.com/intersystems-ru/fhir-terminology-service.git
	```
1. Install IRIS for Health 2020.1 or newer.
2. Open IRIS terminal and set up a new "foundation" namespace, e.g.:
	```
	USER> zn "HSLIB"
	HSLIB> do ##class(HS.Util.Installer.Foundation).Install("terminology")
	```
3. Import classes into the namespace, e.g.:
	```
	HSLIB> zn "terminology"
	TERMINOLOGY> do $System.OBJ.ImportDir("/tmp/fhir-terminology-service/", "*.cls", "ckbud", .err, 1)
	```
	_There is going to be one "class not found" exception if IRIS version is prior to 2020.4. It is safe to just ignore that error._ 

4. Create InteractionsStrategy class for your FHIR Terminology Service endpoint, **or skip this step and use [Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls)**.

	If you choose to create a new InteractionsStrategy class, then do the following:
	1. subclass [iscru.fhir.fts.FTSStrategy](../main/src/cls/iscru/fhir/fts/FTSStrategy.cls),
	2. override ```StrategyKey``` class parameter,
	3. implement ```getCodeTablePackage()```, ```getCodePropertyName()``` and ```getDisplayPropertyName()``` methods, e.g.:
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

	* Refer to [Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls) as an example of a custom InteractionsStrategy class.
	* Additionally implement ```listCodeTableClasses()``` method to enable returning a list of all available code systems (or value sets) in response to a search request without ```url``` parameter.
	* Override ```isExcludedProperty()``` method if any code table class property should not show up in the corresponding CodeSystem resource.
5. _This step is only applicable to 2020.4 or newer versions of InterSystems IRIS._

	Create RepoManager class for your FHIR Terminology Service endpoint (**or skip this step if you are using [Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls)**):
   1. subclass ```HS.FHIRServer.Storage.Json.RepoManager``` system class,
   2. override ```StrategyClass``` and ```StrategyKey``` class parameters as follows:
		```
		Parameter StrategyClass = "<full name of your InteractionsStrategy class>";
		Parameter StrategyKey = "<value of StrategyKey parameter of your InteractionsStrategy class>";
		```

6. Depending on the version of InterSystems IRIS for Health, either create a custom FHIR metadata set (2020.1-2020.3), or import FHIR metadata package (2020.4+) with custom search parameters. This step is a workaround needed for ```$expand``` and ```$validate-code``` operations to support HTTP GET requests.

	6.1. _This step is only applicable to 2020.1-2020.3 versions of InterSystems IRIS for Health (see section 6.2 below for 2020.4+)._

	1. Create ```terminology``` directory within ```<installation directory>/dev/fhir/fhir-metadata``` and copy [dummy-search-parameters.json](../main/src/fhir-search-parameters/dummy-search-parameters.json) file there.

		The file contains definitions of additional search parameters for ValueSet and CodeSystem resources. Those fake search parameters correspond to input parameters of ```$expand``` and ```$validate-code``` operations.

	2. Create custom FHIR metadata set based on R4 set with additional search parameters defined in ```<installation directory>/dev/fhir/fhir-metadata/terminology/dummy-search-parameters.json```.
	
		In the example below the new metadata set is named ```HL7v40terminology``` and the directory containing search parameters definition file is ```C:\InterSystems\IRISHealth20202\dev\fhir\fhir-metadata\terminology```:
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
	6.2. _This step is only applicable to 2020.4 or newer versions of InterSystems IRIS for Health._

	Import FHIR metadata package from [package directory](../main/src/fhir-search-parameters/package) either [using the Management Portal](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/Doc.View.cls?KEY=HXFHIR_server_customize#HXFHIR_server_customize_packages_import) or the interactive utility:
	```
	TERMINOLOGY>do ##class(HS.FHIRServer.ConsoleSetup).Setup()
	What do you want to do?
	  0)  Quit
	  1)  Create a FHIRServer Endpoint
	  2)  Add a profile package to an endpoint
	  3)  Display a FHIRServer Endpoint Configuration
	  4)  Configure a FHIRServer Endpoint
	  5)  Decommission a FHIRServer Endpoint
	  6)  Delete a FHIRServer Endpoint
	  7)  Update the CapabilityStatement Resource
	  8)  Index new SearchParameters for an Endpoint
	  9)  Upload a FHIR metadata package
	  10) Delete a FHIR metadata package
	Choose your Option[1] (0-10): 9
	The following packages are installed:
	[core] hl7.fhir.r3.core@3.0.2: Definitions (API, structures and terminologies) for the R3 version of the FHIR standard
	[core] hl7.fhir.r4.core@4.0.1: Definitions (API, structures and terminologies) for the R4 version of the FHIR standard
	[custom for 4.0.1] hl7.fhir.us.core@3.1.0:
	Enter the path to a directory containing one or more metadata packages (or return to exit)[-]: /tmp/fhir-terminology-service/src/fhir-search-parameters/package
	Found packages:
	  fhir.dummy-search-params@1
	Proceed?[yes] (y/n): yes
	Saving fhir.dummy-search-params@1
	Load Resources: fhir.dummy-search-params@1
	```

7. Create a new FHIR endpoint based on your custom InteractionsStrategy class (or on [Sample.iscru.fhir.fts.SimpleStrategy](../main/samples/cls/Sample/iscru/fhir/fts/SimpleStrategy.cls)). Depending on the version of InterSystems IRIS for Health, either add imported metadata package to the endpoint (2020.4+), or use new metadata set when creating the endpoint (2020.1-2020.3). Note that in 2020.4+ you can create the endpoint using [Management Portal](https://docs.intersystems.com/irisforhealthlatest/csp/docbook/Doc.View.cls?KEY=HXFHIR_server_install).
	
	```
	TERMINOLOGY>do ##class(HS.FHIRServer.ConsoleSetup).Setup()
	What do you want to do?
	  0)  Quit
	  1)  Create a FHIRServer Endpoint
	  2)  Add a profile package to an endpoint
	  3)  Display a FHIRServer Endpoint Configuration
	  4)  Configure a FHIRServer Endpoint
	  5)  Decommission a FHIRServer Endpoint
	  6)  Delete a FHIRServer Endpoint
	  7)  Update the CapabilityStatement Resource
	  8)  Index new SearchParameters for an Endpoint
	  9)  Upload a FHIR metadata package
	  10) Delete a FHIR metadata package
	Choose your Option[9] (0-10): 1
	  1) Json (All Resources stored in a single table as Json text)
	  2) Sample.iscru.fhir.fts.SimpleStrategy (All Resources stored in a single table as Json text)
	Choose the Storage Strategy[1] (1-2): 2
	  1) hl7.fhir.r3.core version 3.0.2 (Definitions (API, structures and terminologies) for the R3 version of the FHIR standard)
	  2) hl7.fhir.r4.core version 4.0.1 (Definitions (API, structures and terminologies) for the R4 version of the FHIR standard)
	Choose the FHIR version for this endpoint[1] (1-2): 2
	The following profile packages are available:
	  1) fhir.dummy-search-params version 1 ()
	  2) hl7.fhir.us.core version 3.1.0 ()
	Enter any package numbers (separated by a comma) or press enter to skip[] (1-2): 1
	...
	```
8. Next, configure the new endpoint: just change DebugMode to 4 leaving default values for everything else:
	```
	What do you want to do?
	  0)  Quit
	  1)  Create a FHIRServer Endpoint
	  2)  Add a profile package to an endpoint
	  3)  Display a FHIRServer Endpoint Configuration
	  4)  Configure a FHIRServer Endpoint
	  5)  Decommission a FHIRServer Endpoint
	  6)  Delete a FHIRServer Endpoint
	  7)  Update the CapabilityStatement Resource
	  8)  Index new SearchParameters for an Endpoint
	  9)  Upload a FHIR metadata package
	  10) Delete a FHIR metadata package
	Choose your Option[4] (0-10): 4
	 
	Which Endpoint do you want to configure?
	  1) /csp/healthshare/terminology/fhir/r4 [enabled] (for Strategy 'Sample.iscru.fhir.fts.SimpleStrategy' and Metadata Set 'hl7.fhir.r4.core@4.0.1,fhir.dummy-search-params@1')
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
9. Import [fhir-terminology-service.postman_collection.json](../main/tests/postman/fhir-terminology-service.postman_collection.json) file into Postman, adjust ```url``` variable defined for the collection and test the service against [Sample.iscru.fhir.fts.model.CodeTable](../main/samples/cls/Sample/iscru/fhir/fts/model/CodeTable.cls) or your own code table classes (depending on whether you've created a custom InteractionsStrategy class). In the latter case, you will need to modify request parameters accordingly.
   * Use the following command to populate [Sample.iscru.fhir.fts.model.CodeTable](../main/samples/cls/Sample/iscru/fhir/fts/model/CodeTable.cls):
		```
		do ##class(Sample.iscru.fhir.fts.model.CodeTable).Populate(10)
		```

## Supported FHIR Interactions
Currently read and search-type interactions are supported for ValueSet and CodeSystem resources. The only supported search parameter for both resources is ```url```.

Supported operations: ```$lookup``` and ```$validate-code``` on CodeSystem, ```$expand``` and ```$validate-code``` on ValueSet.
Both HTTP GET and HTTP POST methods are supported for all operations.

The table below lists some of the possible HTTP GET requests against [Sample.iscru.fhir.fts.model.CodeTable](../main/samples/cls/Sample/iscru/fhir/fts/model/CodeTable.cls) class.
| URI (to be prepended with <br/>```http://<server>:<port><web app path>```) | Description                                                                           |
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
