component {
    public any function formatter() { return identityColumnFormatter; }
    private any function identityColumnFormatter( required any column ) {
        return arguments.column == "queue" ? "invalid_queue" : arguments.column;
    }
}
