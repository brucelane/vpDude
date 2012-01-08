private var airApp : Object = this;
[Bindable]
private var session:Session = Session.getInstance();

//inject a reference to "this" into the HTML dom
private function onHTMLComplete() : void
{
	trace ( "onHTMLComplete" );
	htmlUploadBrowser.domWindow.airApp = airApp;
}

// JAVASCRIPT functions
