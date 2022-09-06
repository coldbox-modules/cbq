component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function run() {
        describe( "queue provider - #getProviderMapping()#", function() {
            it( "does something", function() {
                fail( "test not implemented yet" );
            } );
        } );
    }

    function getProvider() {
        return getWireBox().getInstance( getProviderMapping() );
    }

    function getProviderMapping() {
        throw(
            type = "MissingAbstractMethod",
            message = "This is an abstract method and must be implemented in a subclass."
        );
    }

}