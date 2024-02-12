component extends="cbq.models.Jobs.AbstractJob" {

    function handle() {
        // do nothing
    }

    function before() {
        application.jobBeforeCalled = true;
    }

    function after() {
        application.jobAfterCalled = true;
    }

}