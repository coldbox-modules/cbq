component implements="coldbox.system.aop.MethodInterceptor" {

	property name="log" inject="logbox:logger:{this}";

	/**
	 * Only executes the job interceptor if the Job class matches the provided regex
	 *
	 * @invocation             The invocation object
	 * @invocation.doc_generic coldbox.system.aop.methodInvocation
	 */
	function invokeMethod( required invocation ) {
		if ( !arguments.invocation.getMethodMetadata().keyExists( "jobPattern" ) ) {
			variables.log.error(
				"Could not find the `jobPattern` metadata, even though the AOP matched it. This should not be possible. Allowing the interceptor to fire.",
				{ "invocation" : arguments.invocation }
			);
			return invocation.proceed();
		}

		var jobPattern = arguments.invocation.getMethodMetadata().jobPattern;

		if ( !len( jobPattern ) ) {
			variables.log.warn(
				"Provided job pattern is empty; skipping job interceptor",
				{ "invocation" : arguments.invocation }
			);
			return invocation.proceed();
		}

		if (
			!arguments.invocation.getArgs().keyExists( "data" ) || !arguments.invocation
				.getArgs()
				.data
				.keyExists( "job" )
		) {
			variables.log.error(
				"No job instance in the data for the interceptor. `jobPattern` should only be added on cbq interception points. Allowing the interceptor to fire.",
				{ "invocation" : arguments.invocation }
			);
			return invocation.proceed();
		}

		var jobMetadata = getMetadata( arguments.invocation.getArgs().data.job );
		var jobName = jobMetadata.fullName;

		if ( reFind( jobPattern, jobName ) > 0 ) {
			variables.log.debug(
				"Job Name [#jobName#] passes the provided `jobPattern` regex [#jobPattern#]. Allowing the interceptor to fire.",
				{
					"invocation" : arguments.invocation,
					"jobName" : jobName,
					"jobPattern" : jobPattern
				}
			);
			return invocation.proceed();
		}

		variables.log.debug(
			"Job Name [#jobName#] did not pass the provided `jobPattern` regex [#jobPattern#]. Skipping this interceptor.",
			{
				"invocation" : arguments.invocation,
				"jobName" : jobName,
				"jobPattern" : jobPattern
			}
		);
		return;
	}

}
