
private var airApp : Object = this;

//inject a reference to "this" into the HTML dom
private function onHTMLComplete() : void
{
	trace ( "onHTMLComplete" );
	htmlUploadBrowser.domWindow.airApp = airApp;
}

// JAVASCRIPT functions
