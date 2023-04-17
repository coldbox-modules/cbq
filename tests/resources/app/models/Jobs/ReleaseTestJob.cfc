component extends="cbq.models.Jobs.AbstractJob" {

    function handle() {
        this.release( 2 );
    }

    function onFailure() {
        this.onFailureCalled = true;
    }

}