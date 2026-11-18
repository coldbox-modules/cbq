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
            var recordset = findNoCase( "JSONB_TO_RECORDSET", arguments.data.sql ) > 0;
            variables.counter.rows.append( recordset ? deserializeJSON( arguments.data.bindings[ 1 ].value ).len() : arguments.data.bindings.len() / 5 );
            if ( structKeyExists( variables.counter, "bindings" ) ) {
                variables.counter.bindings.append( arguments.data.bindings.len() );
                variables.counter.json.append( recordset );
            }
        }
    }
}
