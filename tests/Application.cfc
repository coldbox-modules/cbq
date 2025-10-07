component {

    this.name = "cbqTestingSuite" & hash(getCurrentTemplatePath());
    this.sessionManagement  = true;
    this.setClientCookies   = true;
    this.sessionTimeout     = createTimeSpan( 0, 0, 15, 0 );
    this.applicationTimeout = createTimeSpan( 0, 0, 15, 0 );

    testsPath = getDirectoryFromPath( getCurrentTemplatePath() );
    this.mappings[ "/tests" ] = testsPath;
    rootPath = REReplaceNoCase( this.mappings[ "/tests" ], "tests(\\|/)", "" );
    this.mappings[ "/root" ] = rootPath;
    testingModuleRootMapping = listDeleteAt( rootPath, listLen( rootPath, '\/' ), "\/" );
    if ( left( testingModuleRootMapping, 1 ) != "/" ) {
        testingModuleRootMapping = "/" & testingModuleRootMapping;
    }
    this.mappings[ "/testingModuleRoot" ] = testingModuleRootMapping;
    this.mappings[ "/cbq" ] = rootPath;
    this.mappings[ "/app" ] = testsPath & "resources/app";
    this.mappings[ "/coldbox" ] = testsPath & "resources/app/coldbox";
    this.mappings[ "/testbox" ] = rootPath & "/testbox";

    this.datasource = "cbq";

    function onRequestStart() {
        createObject( "java", "java.lang.System" ).setProperty( "ENVIRONMENT", "testing" );
        structDelete( application, "cbController" );
        structDelete( application, "wirebox" );
    }

}
