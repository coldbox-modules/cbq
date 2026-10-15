/** Records real native inserts without changing the QB interception contract. */
component accessors="true" {
    property name="counter";
    public void function processState( required string state, required struct data ) {
        record( argumentCollection = arguments );
    }
    public void function announce( required string state, required struct data ) {
        record( argumentCollection = arguments );
    }
    private void function record( required string state, required struct data ) {
        if ( compareNoCase( arguments.state, "preQBExecute" ) == 0 && reFindNoCase( "^\s*INSERT\b", arguments.data.sql ) ) {
            variables.counter.rows.append( arguments.data.bindings.len() / 5 );
        }
    }
}
