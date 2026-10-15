/** A custom watcher does not change the inherited native persistence capability. */
component extends="cbq.models.Providers.DBProvider" {
    public any function listen( required any pool ) {
        return;
    }
}
