import flash.events.*;
import flash.net.*;
import flash.net.navigateToURL;
import flash.utils.Timer;

import fr.batchass.*;

import mx.collections.XMLListCollection;
import mx.controls.HTML;

import videopong.*;

private var airApp : Object = this;
private var cache:CacheManager;
private var timer:Timer;
[Bindable]
private var session:Session = Session.getInstance();
/*[Bindable]
private var vpFullUrl:String = "";*/

//inject a reference to "this" into the HTML dom
private function onHTMLComplete() : void
{
	trace ( "onHTMLComplete" );
	htmlBrowser.domWindow.airApp = airApp;
}

// JAVASCRIPT functions
public var launchURL:Function = function( url : String ) : void
{
	navigateToURL( new URLRequest( url ) );
}

public var launchE4X:Function = function( e4xResult : String ) : void
{
	trace( "e4x:" + e4xResult );
	var req:URLRequest = new URLRequest(e4xResult);
	var loader:URLLoader = new URLLoader();
	loader.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
	loader.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
	loader.addEventListener( HTTPStatusEvent.HTTP_STATUS, httpStatusHandler );
	loader.addEventListener( ErrorEvent.ERROR, errorEventErrorHandler );
	loader.addEventListener( Event.COMPLETE, e4xLoadComplete );
	loader.dataFormat = URLLoaderDataFormat.TEXT;
	loader.load(req);
	timer = new Timer(1000);
	timer.addEventListener( TimerEvent.TIMER, checkRemaining );
	timer.start();
}
private function checkRemaining( event:Event ): void 
{
	if (cache) remaining.text = "Files remaining to download: "+ cache.filesRemaining;			
}
private function e4xLoadComplete( event:Event ):void
{
	var loader:URLLoader = event.target as URLLoader;
	var clips:Clips = Clips.getInstance();
	var tags:Tags = Tags.getInstance();
	
	// downloaded one clip xml
	var clipXml:XML = XML( loader.data );
	var clipId:String = clipXml.@id;
	// if clip exists
	Util.log( 'e4xLoadComplete, clipExists: ' + clips.clipIsNew( clipId ) );

	if ( clips.clipIsNew( clipId ) )
	{
		Util.log( 'e4xLoadComplete, clip does not exist' );
		// download thumbs and video if not in cache
		if ( !cache ) cache = new CacheManager( session.dldFolderPath );
		cache.downloadClipFiles( clipXml..urlthumb1, clipXml..urldownload, clipXml..urlpreview );
		clipXml.dlddate = Util.nowDate;
		// add originaltags
		var clipOriginalTagList:XMLList = clipXml..tag as XMLList;
		for each ( var originalClipTag:XML in clipOriginalTagList )
		{
			var clipOriginalXmlTag:XML = <originaltag name={originalClipTag.@name} creationdate={Util.nowDate}  />;
			clipXml.tags.appendChild( clipOriginalXmlTag );	
		}
		// add clip name and creator name tags
		var creatorTag:String = clipXml..creator.@name.toString().toLowerCase();
		var creatorXmlTag:XML = <tag name={creatorTag} creationdate={Util.nowDate}  />;
		var creatorAddedXmlTag:XML = <addedtag name={creatorTag} creationdate={Util.nowDate}  />;
		clipXml..tags.appendChild( creatorXmlTag );
		clipXml..tags.appendChild( creatorAddedXmlTag );
		var clipTag:String = clipXml..clip.@name.toString().toLowerCase();
		var clipXmlTag:XML = <tag name={clipTag} creationdate={Util.nowDate}  />;
		var clipAddedXmlTag:XML = <addedtag name={clipTag} creationdate={Util.nowDate}  />;
		clipXml..tags.appendChild( clipXmlTag );
		clipXml..tags.appendChild( clipAddedXmlTag );
		
		// xml list of tags
		var clipXmlTagList:XMLList = clipXml..tags.tag as XMLList;
		var newTag:Boolean = false;
		var foundNewTag:Boolean;
		
	
		//add new clip if exists
		clips.addNewClip( clipId, clipXml );
		
		//TODO optimize
		for each ( var oneTag:XML in clipXmlTagList )
		{
			foundNewTag = true;
			var appTagList:XMLList = tags.TAGS_XML..tag as XMLList;
			for each ( var appTag:XML in appTagList )
			{
				if ( appTag.@name==oneTag.@name )
				{
					foundNewTag = false;
				}
			}
			if ( foundNewTag )
			{
				tags.TAGS_XML.appendChild( oneTag );
				newTag = true;	
			}
		}
		if ( newTag )
		{
			tags.writeTagsFile();
		}
		
	}
	else
	{
		Util.log( 'e4xLoadComplete, clip exists' );

	}
}

public function errorEventErrorHandler(event:ErrorEvent):void
{
	Util.log( 'An ErrorEvent has occured: ' + event.text );
}	
private function ioErrorHandler( event:IOErrorEvent ):void
{
	Util.log( 'TabBrowser, An IO Error has occured: ' + event.text );
}    
// only called if a security error detected by flash player such as a sandbox violation
private function securityErrorHandler( event:SecurityErrorEvent ):void
{
	Util.log( "TabBrowser, securityErrorHandler: " + event.text );
}		
//  after a file upload is complete or attemted the server will return an http status code, code 200 means all is good anything else is bad.
private function httpStatusHandler( event:HTTPStatusEvent ):void 
{  
	Util.log( "TabBrowser, httpStatusHandler, status(200 is ok): " + event.status );
}
