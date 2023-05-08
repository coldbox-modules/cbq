component {

	property name="settings" inject="coldbox:moduleSettings:cbq";
    property name="qb" inject="provider:QueryBuilder@qb";
	property name="config" inject="provider:Config@cbq";

    function onCBQJobFailed( event, data ) {
        if ( !variables.settings.logFailedJobs.enabled ) {
            return;
        }

		var connectionName = arguments.data.job.getConnection();
		param connectionName = variables.config.getDefaultConnectionName();
		var queueName = arguments.data.job.getQueue();

		if ( isNull( queueName ) ) {
			var connection = variables.config.getConnection( connectionName );
			queueName = connection.getDefaultQueue();
		}

        qb.table( variables.settings.logFailedJobs.tableName )
            .insert(
                values = {
                    "connection": connectionName,
                    "queue": queueName,
                    "mapping": arguments.data.job.getMapping(),
                    "memento": serializeJSON( arguments.data.job.getMemento() ),
                    "properties": serializeJSON( arguments.data.job.getProperties() ),
                    "exceptionType": {
						"value": arguments.data.exception.type ?: "",
						"cfsqltype": "CF_SQL_VARCHAR",
						"null": ( arguments.data.exception.type ?: "" ) == "",
						"nulls": ( arguments.data.exception.type ?: "" ) == ""
					},
                    "exceptionMessage": arguments.data.exception.message,
					"exceptionDetail": {
						"value": arguments.data.exception.detail ?: "",
						"cfsqltype": "CF_SQL_VARCHAR",
						"null": ( arguments.data.exception.detail ?: "" ) == "",
						"nulls": ( arguments.data.exception.detail ?: "" ) == ""
					},
					"exceptionExtendedInfo": {
						"value": arguments.data.exception.extendedInfo ?: "",
						"cfsqltype": "CF_SQL_VARCHAR",
						"null": ( arguments.data.exception.extendedInfo ?: "" ) == "",
						"nulls": ( arguments.data.exception.extendedInfo ?: "" ) == ""
					},
                    "exceptionStackTrace": arguments.data.exception.stackTrace,
                    "exception": serializeJSON( arguments.data.exception ),
                    "failedDate": now()
                },
                options = variables.settings.logFailedJobs.queryOptions
            );
    }

}