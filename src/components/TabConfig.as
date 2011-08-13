import components.*;

import flash.desktop.NativeApplication;
import flash.desktop.NativeProcess;
import flash.desktop.NativeProcessStartupInfo;
import flash.events.*;
import flash.filesystem.File;
import flash.filesystem.FileMode;
import flash.utils.Timer;

import fr.batchass.Util;
import fr.batchass.readTextFile;
import fr.batchass.writeTextFile;

import mx.collections.ArrayCollection;
import mx.events.FlexEvent;

import spark.events.TextOperationEvent;

import videopong.Clips;
import videopong.Tags;

[Bindable]
private var ownFiles:ArrayCollection;

private var defaultConfigXmlPath:String = 'config' + File.separator + '.vpDudeConfig';

[Bindable]
private var lblWidth:int = 180;
[Bindable]
private var tiWidth:int = 350;

private var isConfigured:Boolean = false;

[Bindable]
public var userName:String = "";
[Bindable]
private var hiddenPassword:String = "";
[Bindable]
private var vpDbPath:String = "";

private var password:String = "";
private var passwordChanged:Boolean = false;

[Bindable]
private var reso:String = "320x240";

public static var CONFIG_XML:XML;
private var OWN_CLIPS_XML:XML;
private var validExtensions:Array = ["avi", "mov", "mp4", "flv", "qt", "swf", "mpeg", "mpg", "h264"];

private var moviesToConvert:Array = new Array();
private var thumbsToConvert:Array = new Array();

private var newClips:Array = new Array();

private var timer:Timer;
[Bindable]
private var busy:Boolean = false;
private var thumb1:String;
private var tPath:String;
private var currentThumb:int;

[Bindable]
private var countNew:int = 0;
[Bindable]
private var countDeleted:int = 0;
[Bindable]
private var countChanged:int = 0;
[Bindable]
private var countDone:int = 0;
[Bindable]
private var countError:int = 0;
[Bindable]
private var countTotal:int = 0;
[Bindable]
private var countNoChange:int = 0;
private var nochgFiles:String = "";
private var newFiles:String = "";
private var delFiles:String = "";
private var chgFiles:String = "";
private var errFiles:String = "";
private var allFiles:String = "";
private var currentFilename:String = "";
private var startFFMpegProcess:NativeProcess;

protected function config_preinitializeHandler(event:FlexEvent):void
{
	try
	{
		var configFile:File = File.applicationStorageDirectory.resolvePath( defaultConfigXmlPath );
		
		if ( !configFile.exists )
		{
			Util.log( "config.xml does not exist" );
		}
		else
		{
			Util.log( "config.xml exists, load the file xml" );
			CONFIG_XML = new XML( readTextFile( configFile ) );
			
			userName = CONFIG_XML..username[0].toString();
			parentDocument.userName = userName;
			password = CONFIG_XML..pwd[0].toString();
			for ( var i:uint = 0; i < password.length; i++ )
			{
				hiddenPassword += "*";
			}
			reso = CONFIG_XML..reso[0].toString();
			parentDocument.vpFolderPath = File.applicationStorageDirectory.nativePath;
/*			parentDocument.vpFolderPath = CONFIG_XML..db[0].toString();
			if ( !parentDocument.vpFolderPath || parentDocument.vpFolderPath.length == 0 )
			{
				parentDocument.vpFolderPath = File.applicationStorageDirectory.nativePath;
			}*/			
			vpDbPath = parentDocument.vpFolderPath;
			parentDocument.ownFolderPath = CONFIG_XML..own[0].toString();
			isConfigured = true;
		}
	}
	catch ( e:Error )
	{	
		var msg:String = 'Error loading config.xml file: ' + e.message;
		parentDocument.statusText.text = msg;
		Util.log( msg );
	}
	createEncodedVars();
	timer = new Timer(1000);
	timer.addEventListener(TimerEvent.TIMER, processConvert);
	timer.start();

}
private function createEncodedVars():void
{
	var fullUrlToEncode:String = parentDocument.vpUrl + "?login=" + escape(userName) + "&password=" + escape(password);
	var fullUpUrlToEncode:String = parentDocument.vpUpUrl + "?login=" + escape(userName) + "&password=" + escape(password);
	parentDocument.vpFullUrl = fullUrlToEncode;
	parentDocument.vpUploadUrl = fullUpUrlToEncode;

}
protected function config_creationCompleteHandler(event:FlexEvent):void
{
	if ( isConfigured )
	{
		Util.log( "config_creationCompleteHandler, isConfigured is true" );
		Util.log( "config_creationCompleteHandler, parentDocument: " + parentDocument );
		if (parentDocument )
		{	
			parentDocument.addTabs();
		}
		else
		{
			Util.log( "config_creationCompleteHandler, parentDocument is null, maybe no internet cnx? " );		
		}
	}
	else
	{
		parentDocument.vpFolderPath = File.documentsDirectory.resolvePath( "vpdude/" ).nativePath;
		parentDocument.ownFolderPath = File.documentsDirectory.resolvePath( "vpdude/own/" ).nativePath;
		vpDbPath = parentDocument.vpFolderPath;
	}
}
protected function pwdTextInput_focusInHandler(event:FocusEvent):void
{
	if ( pwdTextInput.text.indexOf("*") > -1 ) pwdTextInput.text ="";
}
protected function pwdTextInput_changeHandler(event:TextOperationEvent):void
{
	passwordChanged = true;
}
protected function applyBtn_clickHandler(event:MouseEvent):void
{
	var isChanged:Boolean = false;
	if ( userName != userTextInput.text || parentDocument.ownFolderPath != ownTextInput.text || reso != resoTextInput.text ) 
	{
		isChanged = true;
		userName = userTextInput.text;
		parentDocument.userName = userName;
		parentDocument.ownFolderPath = ownTextInput.text;
		reso = resoTextInput.text;
		checkFolder( parentDocument.ownFolderPath );
	}
	if ( passwordChanged ) 
	{
		isChanged = true;
		password = pwdTextInput.text;
		hiddenPassword = "";
		for ( var i:uint = 0; i < password.length; i++ )
		{
			hiddenPassword += "*";
		}
		pwdTextInput.text = hiddenPassword;
	}
	/*if ( parentDocument.vpFolderPath != dbTextInput.text ) 
	{
		isChanged = true;
		// Copy db to new location
		copyFolders( new File( parentDocument.vpFolderPath ), dbTextInput.text );
	}*/
	if ( isChanged ) parentDocument.statusText.text = "Configuration saved";
	checkFolder( parentDocument.vpFolderPath );
	writeFolderXmlFile();

	createEncodedVars();
	if ( !isConfigured )
	{
		isConfigured = true;
		parentDocument.addTabs();
	}
}

// Copy all files in a directory structure including subdirectories.
/*public function copyFolders( sourceDir:File, destDir:String, destDirRoot:String="" ):Boolean
{
	var str:String = "";
	var copySuccess:Boolean = true
	for each( var lstFile:File in sourceDir.getDirectoryListing() )
	{
		if( lstFile.isDirectory )
		{
			var sourcePath:String = lstFile.nativePath;
			var newSubdir:String = sourcePath.substr( parentDocument.vpFolderPath.length );
			if ( destDirRoot == "") destDirRoot = destDir;
			var newDestDir:String = destDirRoot + newSubdir;
			//recursively call function
			copyFolders( lstFile, newDestDir, destDirRoot );
		}
		else
		{
			//file: copy
			var sourceFile:File = lstFile;
			var destFile:File = new File( destDir + "/" + lstFile.name );
			sourceFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			sourceFile.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
			try 
			{
				sourceFile.copyTo( destFile );
			}
			catch (error:Error)
			{
				Util.errorLog( "CopyFolders Error:" + error.message );
				copySuccess = false;
			}
		}
	}	
	return copySuccess;
}*/

private function writeFolderXmlFile():void
{
	CONFIG_XML = <config> 
					<username>{userName}</username>
					<pwd>{password}</pwd>
					<db>{parentDocument.vpFolderPath}</db>
					<own>{parentDocument.ownFolderPath}</own>
					<reso>{reso}</reso>
				 </config>;
	var folderFile:File = File.applicationStorageDirectory.resolvePath( defaultConfigXmlPath );
	// write the text file
	writeTextFile( folderFile, CONFIG_XML );					
}
protected function browseConfigPathBtn_clickHandler(event:MouseEvent):void
{
	var file:File = File.documentsDirectory;
	file.addEventListener(Event.SELECT, dbFolderSelection);
	file.addEventListener(Event.CANCEL, dbFolderSelection);
	parentDocument.statusText.text = "Choose where the database files will be stored.";
	
	file.browseForDirectory( "Select a location to store the database files." ); 
}
protected function browseOwnPathBtn_clickHandler(event:MouseEvent):void
{
	var file:File = File.documentsDirectory;
	file.addEventListener(Event.SELECT, ownFolderSelection);
	file.addEventListener(Event.CANCEL, ownFolderSelection);
	parentDocument.statusText.text = "Choose where your own videos are located.";
	
	file.browseForDirectory( "Select where your own videos are located." ); 
}
private function dbFolderSelection(event:Event):void 
{
	var file:File = event.currentTarget as File;
	file.removeEventListener(Event.SELECT, dbFolderSelection);
	file.removeEventListener(Event.CANCEL, dbFolderSelection);
	
	if (event.type === Event.SELECT) 
	{
		vpDbPath = file.nativePath;
	}		
}
private function ownFolderSelection(event:Event):void 
{
	var file:File = event.currentTarget as File;
	file.removeEventListener(Event.SELECT, ownFolderSelection);
	file.removeEventListener(Event.CANCEL, ownFolderSelection);
	
	if (event.type === Event.SELECT) 
	{
		parentDocument.ownFolderPath = file.nativePath;
	}		
}

private function checkFolder( folderPath:String ):void 
{
	var folder:File = new File( folderPath );
	var folderPath:String = folder.nativePath.toString();
	// creates folder if it does not exists
	if (!folder.exists) 
	{
		parentDocument.statusText.text = 'Creating folder: ' + folderPath;
		Util.log('Creating folder: ' + folderPath);
		// create the directory
		folder.createDirectory();
	}
	if (!folder.exists) 
	{
		parentDocument.statusText.text = 'Could not create: ' + folderPath;
		Util.log('Could not create: ' + folderPath);
	}
	else
	{
		//create subfolder structure
		var dldFolder:File = new File( parentDocument.dldFolderPath );
		dldFolder.createDirectory();
		Util.log('Created: ' + parentDocument.dldFolderPath);
		var dbFolder:File = new File( parentDocument.dbFolderPath );
		dbFolder.createDirectory();
		Util.log('Created: ' + parentDocument.dbFolderPath);	
	}
}

protected function exploreBtn_clickHandler(event:MouseEvent):void
{
	// added june 2011 for mac: "file://"
	if ( parentDocument.os == "Mac" )
	{
		navigateToURL(new URLRequest("file://" + parentDocument.ownFolderPath));
	}
	else
	{
		navigateToURL(new URLRequest( parentDocument.ownFolderPath));
		//var file:File = new File( parentDocument.ownFolderPath );
		//file.browse();
	}
}
protected function resyncBtn_clickHandler(event:MouseEvent):void
{
	if ( parentDocument.ownFolderPath != ownTextInput.text ) 
	{
		parentDocument.ownFolderPath = ownTextInput.text;
	}
	countNew = 0;
	countDeleted = 0;
	countChanged = 0;
	countDone = 0;
	countError = 0;
	countNoChange = 0;
	nochgFiles = "";
	newFiles = "";
	delFiles = "";
	chgFiles = "";
	errFiles = "";
	allFiles = "";
	
	var selectedDirectory:File = new File( parentDocument.ownFolderPath );
	// Get directory listing
	ownFiles = new ArrayCollection( selectedDirectory.getDirectoryListing() );
	countTotal = 0;
	
	parentDocument.statusText.text = "Processing " + ownFiles.length + " file(s)";
	currentFilename = "";
	//countTotal = ownFiles.length;
	syncStatus.text = "(" + countDone + "/" + countTotal + ")";
	// delete inexistent files from db
	var clips:Clips = Clips.getInstance();
	var clipList:XMLList = clips.CLIPS_XML..video as XMLList;
	for each ( var clip:XML in clipList )
	{
		//test if own file
		if ( clip.@urllocal )
		{
			var searchedFile:File = new File( parentDocument.ownFolderPath + File.separator + clip.@urllocal );
			// search for file is own folder
			if ( !searchedFile.exists ) 
			{
				// delete xml file
				deleteFile( parentDocument.dbFolderPath + File.separator + clip.@id + ".xml" );
				// delete in clips.xml
				clips.deleteClip( clip.@id, clip.@urllocal );
				//TODO delete tag in tags.xml
				//var tags:Tags = Tags.getInstance();
				//tags.
				// delete thumbs
				deleteFile( clip.urlthumb1 );
				deleteFile( clip.urlthumb2 );
				deleteFile( clip.urlthumb3 );
				// delete thumbs folder
				deleteFolder( parentDocument.dldFolderPath+ File.separator + "thumbs" + File.separator + clip.@id );
				// delete preview
				deleteFile( clip.urlpreview );
				// delete preview folder
				deleteFolder( parentDocument.dldFolderPath+ File.separator + "preview" + File.separator + clip.@id );
				countDeleted++;
				delFiles += clip.@id + " ";
			}		
		}	 	
	}

	// read all files in the folder
	processAllFiles( selectedDirectory );
	
}
// Process all files in a directory structure including subdirectories.
public function processAllFiles( selectedDir:File ):void
{
	var clips:Clips = Clips.getInstance();
	for each( var lstFile:File in selectedDir.getDirectoryListing() )
	{
		if( lstFile.isDirectory )
		{
			//recursively call function
			processAllFiles( lstFile );
		}
		else
		{
			Util.log('processAllFiles, not directory: ' + lstFile.name);
			countTotal++;
			allFiles += lstFile.name + " ";
			var clipPath:String = lstFile.nativePath;
			var clipModificationDate:String = lstFile.modificationDate.toUTCString();
			var clipSize:String = lstFile.size.toString();			
			var clipRelativePath:String = clipPath.substr( parentDocument.ownFolderPath.length + 1 );
			var clipGeneratedName:String = Util.getFileNameWithSafePath( clipRelativePath );
			var clipGeneratedTitle:String = Util.getFileName( clipRelativePath );
			var clipGeneratedTitleWithoutExtension:String = Util.getFileNameWithoutExtension( clipRelativePath );
			var thumbsPath:String = parentDocument.dldFolderPath + "/thumbs/" + clipGeneratedName + "/";
			var swfPath:String = parentDocument.dldFolderPath + "/preview/" + clipGeneratedName + "/";
			
			//check if it is a video file
			if ( validExtensions.indexOf( lstFile.extension.toLowerCase() ) > -1 )
			{
				if ( clips.newClip( clipRelativePath ) )
				{
					countNew++;
					newFiles += clipGeneratedName + " ";
					log.text += "New clip: " + clipGeneratedName + "\n";
					//var clipId:String = Util.nowDate;
					var thumbsFolder:File = new File( thumbsPath );
					// creates folder if it does not exists
					if ( !thumbsFolder.exists ) 
					{
						// create the directory
						thumbsFolder.createDirectory();
					}
					var previewFolder:File = new File( swfPath );
					// creates folder if it does not exists
					if ( !previewFolder.exists ) 
					{
						// create the directory
						previewFolder.createDirectory();
					}
					log.text += "\nGenerating thumbs with ffmpeg for " + clipPath;
					thumbsToConvert.push({clipLocalPath:clipPath,tPath:thumbsPath,tNumber:1});
					thumbsToConvert.push({clipLocalPath:clipPath,tPath:thumbsPath,tNumber:2});
					thumbsToConvert.push({clipLocalPath:clipPath,tPath:thumbsPath,tNumber:3});
					log.text += "\nGenerating preview with ffmpeg" + clipPath;
					moviesToConvert.push({clipLocalPath:clipPath,swfLocalPathswfPath:swfPath, clipGenName:clipGeneratedName, snd:false });
					// create XML
					OWN_CLIPS_XML = <video id={clipGeneratedName} urllocal={clipRelativePath} datemodified={clipModificationDate} size={clipSize}> 
										<urlthumb1>{thumbsPath + "thumb1.jpg"}</urlthumb1>
										<urlthumb2>{thumbsPath + "thumb2.jpg"}</urlthumb2>
										<urlthumb3>{thumbsPath + "thumb3.jpg"}</urlthumb3>
										<urlpreview>{swfPath + clipGeneratedName + ".swf"}</urlpreview>
										<clip name={clipGeneratedTitle} />
										<creator name={userName}/>
										<tags>
											<tag name="own"/>
										</tags>
									</video>;
					var tags:Tags = Tags.getInstance();
					tags.addTagIfNew( "own" );
					if ( clipRelativePath.length > 0 )
					{
						var folders:Array = clipRelativePath.split( File.separator );
						
						for each (var folder:String in folders)
						{
							if ( clipGeneratedTitle == folder) folder = clipGeneratedTitleWithoutExtension;
							tags.addTagIfNew( folder );
							var folderXmlTag:XML = <tag name={folder} creationdate={Util.nowDate} />;
							OWN_CLIPS_XML.tags.appendChild( folderXmlTag );
						}
					}
					newClips.push({clipName:clipGeneratedName,ownXml:OWN_CLIPS_XML,cPath:clipPath});
				}
				else
				{
					log.text += "Clip already in db: " + clipGeneratedName + "\n";
					// check if file changed
					if ( clips.fileChanged( clipRelativePath, parentDocument.ownFolderPath ) )
					{
						// delete thumbs and preview swf
						deleteThumbs( thumbsPath );
						deleteFile( swfPath + clipGeneratedName + ".swf" );
						// modify xml
						// read clip xml file
						var localClipXMLFile:String = parentDocument.dbFolderPath + File.separator + clipGeneratedName + ".xml" ;
						var clipXmlFile:File = new File( localClipXMLFile );
						var clipXml:XML = new XML( readTextFile( clipXmlFile ) );					
						clipXml.@datemodified = clipModificationDate;
						clipXml.@size = clipSize;
						
						// write the text file
						clips.writeClipXmlFile( clipGeneratedName, clipXml );					
						
						// modify clips.xml
						clips.deleteClip( clipGeneratedName, clipRelativePath );
						// generate new files
						newClips.push({clipName:clipGeneratedName,ownXml:clipXml,cPath:clipPath});
						countChanged++;
						countDone++;
						chgFiles += clipGeneratedName + "";
					}
					else
					{
						countDone++;
						countNoChange++;
						nochgFiles += clipGeneratedName + " ";
					}
				}
			}
			else
			{
				countError++;
				countDone++;
				// errorFilenames += clipPath + "\n";
				log.text += "File extension not in permitted list: " + clipGeneratedName + "\n";
			}
		}
	}	
}
private function deleteThumbs( thumbsPath:String ): void 
{
	deleteFile( thumbsPath + "thumb1.jpg" );
	deleteFile( thumbsPath + "thumb2.jpg" );
	deleteFile( thumbsPath + "thumb3.jpg" );
}
private function deleteFile( path:String ): void 
{
	var file:File = new File( path );
	// delete file if it exists
	if ( file.exists ) 
	{
		file.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
		file.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
		file.moveToTrash();
		//TODO delete event listeners
	}
}
private function deleteFolder( path:String ): void 
{
	var folder:File = new File( path );
	// delete file if it exists
	if ( folder.exists ) 
	{
		folder.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
		folder.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
		folder.moveToTrash();
		//TODO delete event listeners
	}
}
private function processConvert(event:Event): void 
{
	if ( syncStatus ) syncStatus.text = "(" + countDone + "/" + countTotal + ")";
	if ( !busy )
	{
		if ( thumbsToConvert.length > 0 )
		{
			busy = true;
			currentThumb = thumbsToConvert[0].tNumber;
			ffout.text += "Converting: " + thumbsToConvert[0].clipLocalPath + "\n";
			Util.ffMpegOutputLog( "processConvert: " + "Converting " + thumbsToConvert[0].clipLocalPath + "\n" );
			execute( thumbsToConvert[0].clipLocalPath, thumbsToConvert[0].tPath, thumbsToConvert[0].tNumber );
			thumbsToConvert.shift();
		}
		else
		{	
			if ( newClips.length > 0 )
			{
				var clips:Clips = Clips.getInstance();
				clips.addNewClip( newClips[0].clipName, newClips[0].ownXml, newClips[0].cPath );
				newClips.shift();
			}
			else
			{	
				if ( moviesToConvert.length > 0 )
				{
					busy = true;
					generatePreview( moviesToConvert[0].clipLocalPath, moviesToConvert[0].swfLocalPathswfPath, moviesToConvert[0].clipGenName, moviesToConvert[0].snd );
					moviesToConvert.shift();
				}
				else
				{
					// all is converted and finished
					if (log && countTotal > 0)
					{
						ffout.text = "Completed:\n [" + allFiles + "]\n";
						ffout.text += "- newly indexed: " + countNew + " clip(s) [" + newFiles + "]\n";
						ffout.text += "- changed: " + countChanged + " clip(s) [" + chgFiles + "]\n";
						ffout.text += "- deleted: " + countDeleted + " clip(s) [" + delFiles + "]\n";
						ffout.text += "- no change: " + countNoChange + " clip(s) [" + nochgFiles + "]\n";
						if ( countError > 0 )
						{
							ffout.text += "- could not convert: " + countError + " clip(s) [" + errFiles + "]\n";
						}
						
					}
				}
			}
		}
	}
	else
	{
		//busy
		if ( !startFFMpegProcess.running ) busy = false;
	}
	if ( busy )
	{
		this.setCurrentState("Busy");	
	}
	else
	{
		if ( ( thumbsToConvert.length == 0 ) && ( moviesToConvert.length == 0 ) && ( newClips.length == 0 ) )
		{
			this.setCurrentState("Normal");
		}
	}
}
private function generatePreview( ownVideoPath:String, swfPath:String, clipGeneratedName:String, sound:Boolean = false ):void
{
	currentFilename = clipGeneratedName;
	parentDocument.statusText.text = "Converting to swf: " + ownVideoPath;
	// Start the process
	try
	{
		if ( ownVideoPath.indexOf(".swf") > -1 )
		{
			copySwf( ownVideoPath, swfPath + clipGeneratedName + ".swf" );
		}
		var ffMpegExecutable:File = File.applicationStorageDirectory.resolvePath( parentDocument.vpFFMpegExePath );
		if ( !ffMpegExecutable.exists )
		{
			Util.log( "generatePreview, ffMpegExecutable does not exist: " + parentDocument.vpFFMpegExePath );
		}
		else
		{
			Util.log( "generatePreview, ffMpegExecutable exists: " + parentDocument.vpFFMpegExePath );
		}
		ffout.text += "generatePreview, Converting " + clipGeneratedName + " to swf: " + swfPath + clipGeneratedName + ".swf" + "\n";
		Util.ffMpegOutputLog( "NativeProcess generatePreview: " + "Converting " + clipGeneratedName + " to swf: " + swfPath + clipGeneratedName + ".swf" + "\n" );
		
		var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		nativeProcessStartupInfo.executable = ffMpegExecutable;
		//nativeProcessStartupInfo.executable = File.applicationStorageDirectory.resolvePath( parentDocument.vpFFMpegExePath );
		Util.log("generatePreview,ff path:"+ ffMpegExecutable.nativePath );
		var processArgs:Vector.<String> = new Vector.<String>();
		var i:int = 0;
		processArgs[i++] = "-i";
		processArgs[i++] = ownVideoPath;
		processArgs[i++] = "-b";
		processArgs[i++] = "400k";
		if ( sound )
		{
			processArgs[i++] = "-ar";
			processArgs[i++] = "44100";
			processArgs[i++] = "-ab";
			processArgs[i++] = "128k";
			//-ar 22050 -ab 56k
			/*processArgs[i++] = "-acodec";
			processArgs[i++] = "libfaac";
			processArgs[i++] = "-ar";
			processArgs[i++] = "44100";
			processArgs[i++] = "-ab";
			processArgs[i++] = "128k";
			processArgs[i++] = "-ac";
			processArgs[i++] = "2";*/
		}
		else
		{
			processArgs[i++] = "-an";
		}
		processArgs[i++] = "-f";
		processArgs[i++] = "avm2";
		processArgs[i++] = "-s";
		processArgs[i++] = reso;// "320x240";
		processArgs[i++] = swfPath + clipGeneratedName + ".swf";
		processArgs[i++] = "-y";
		nativeProcessStartupInfo.arguments = processArgs;
		startFFMpegProcess = new NativeProcess();
		startFFMpegProcess.start(nativeProcessStartupInfo);
		startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,
			outputDataHandler);
		startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA,
			errorMovieDataHandler);
		startFFMpegProcess.addEventListener(Event.STANDARD_OUTPUT_CLOSE, processClose );
		startFFMpegProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit);
	}
	catch (e:Error)
	{
		Util.log( "generatePreview, NativeProcess Error: " + e.message );
		busy = false;
	}
}
private function copySwf( src:String, dest:String ):void
{
	var sourceFile:File = new File( src );
	var destFile:File = new File( dest );
	sourceFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
	sourceFile.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
	try 
	{
		sourceFile.copyTo( destFile );
	}
	catch (error:Error)
	{
		Util.errorLog( "copySwf Error:" + error.message );
	}
	
}
private function onExit(evt:NativeProcessExitEvent):void
{
	Util.ffMpegOutputLog( "Process ended with code: " + evt.exitCode); 
}
//thumbs
private function execute( ownVideoPath:String, thumbsPath:String, thumbNumber:uint ):void
{
	parentDocument.statusText.text = "Creating thumb: " + ownVideoPath;
	// Start the process
	try
	{
		tPath = thumbsPath;
		var ffMpegExecutable:File = File.applicationStorageDirectory.resolvePath(  parentDocument.vpFFMpegExePath );
		if ( !ffMpegExecutable.exists )
		{
			Util.log( "execute, ffMpegExecutable does not exist: " + parentDocument.vpFFMpegExePath );
		}
		else
		{
			Util.log( "execute, ffMpegExecutable exists: " + parentDocument.vpFFMpegExePath );
		}
		var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
		nativeProcessStartupInfo.executable = ffMpegExecutable;

		Util.log( "execute, ffMpegExecutable path: " + File.applicationStorageDirectory.resolvePath(  parentDocument.vpFFMpegExePath ).nativePath );
			                  		
		if (thumbNumber == 1) 
		{
			thumb1 = thumbsPath + "thumb" + thumbNumber + ".jpg" 
		}
		else thumb1 = "";
		ffout.text += "execute, Converting " + ownVideoPath + " to thumb " + thumb1 + "\n";
		Util.ffMpegOutputLog( "NativeProcess execute: " + "Converting " + ownVideoPath + " to thumb " + thumb1 + "\n" );
		
		var processArgs:Vector.<String> = new Vector.<String>();
		processArgs[0] = "-i";
		processArgs[1] = ownVideoPath;
		processArgs[2] = "-vframes";
		processArgs[3] = "1";
		processArgs[4] = "-f";
		processArgs[5] = "image2";
		processArgs[6] = "-vcodec";
		processArgs[7] = "mjpeg";
		processArgs[8] =  "-s";
		processArgs[9] = "100x74"; //Frame size must be a multiple of 2
		processArgs[10] =  "-ss";
		processArgs[11] = thumbNumber.toString();
		processArgs[12] = thumbsPath + "thumb" + thumbNumber + ".jpg";
		processArgs[13] = "-y";
		nativeProcessStartupInfo.arguments = processArgs;

		startFFMpegProcess = new NativeProcess();
		startFFMpegProcess.start(nativeProcessStartupInfo);
		startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,
			outputDataHandler);
		startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA,
			errorOutputDataHandler);
	}
	catch (e:Error)
	{
		Util.log( "execute, NativeProcess Error: " + e.message );
		busy = false;
	}
}
private function outputDataHandler(event:ProgressEvent):void
{
	var process:NativeProcess = event.target as NativeProcess;
	var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
	resetConsole();
	log.text += data;
	Util.ffMpegOutputLog( "NativeProcess outputDataHandler: " + data );
}
private function processClose(event:Event):void
{
	var process:NativeProcess = event.target as NativeProcess;
	Util.ffMpegOutputLog( "NativeProcess processClose" );
}
private function errorOutputDataHandler(event:ProgressEvent):void
{
	var process:NativeProcess = event.target as NativeProcess;
	var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
	resetConsole();
	log.text += data;
	if (data.indexOf("muxing overhead")>-1) 
	{
		if ( thumb1.length > 0 )
		{
			//file: copy
			var sourceFile:File = new File( thumb1 );
			var destFile:File = new File( tPath + "thumb2.jpg" );
			sourceFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
			sourceFile.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
			try 
			{
				sourceFile.copyTo( destFile );
				var destFile2:File = new File( tPath + "thumb3.jpg" );
				sourceFile.copyTo( destFile2 );
			}
			catch (error:Error)
			{
				Util.errorLog( "errorOutputDataHandler Error:" + error.message );
			}
		}
		busy = false;
	}
	if (data.indexOf("swf: I/O error occurred")>-1)
	{ 
		busy = false;
		//copySwf();
	}
	if (data.indexOf("Unknown format")>-1)
	{ 
		busy = false;
	}
	Util.ffMpegErrorLog( "NativeProcess errorOutputDataHandler: " + data );
}
private function errorMovieDataHandler(event:ProgressEvent):void
{
	var process:NativeProcess = event.target as NativeProcess;
	var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
	resetConsole();
	log.text += data;
	if (data.indexOf("muxing overhead")>-1)
	{
		//countDone++;
		busy = false;
	}
	if (data.indexOf("swf: I/O error occurred")>-1)
	{ 
		//countDone++;
		countError++;
		errFiles += currentFilename + " ";
		busy = false;
	}
	if (data.indexOf("Unknown format")>-1)
	{ 
		//countDone++;
		countError++;
		errFiles += currentFilename + " ";
		busy = false;
	}
	if (data.indexOf("already exists. Overwrite")>-1)
	{ 	
		countDone--;
		busy = false;
	}
	if ( !busy ) countDone++;
	Util.ffMpegMovieErrorLog( "NativeProcess errorOutputDataHandler: " + data );
}
private function resetConsole():void
{
	if ( log.text.length > 500 ) log.text = "";
}
private function ioErrorHandler( event:IOErrorEvent ):void
{
	Util.log( 'TabConfig, An IO Error has occured: ' + event.text );
}    
// only called if a security error detected by flash player such as a sandbox violation
private function securityErrorHandler( event:SecurityErrorEvent ):void
{
	Util.log( "TabConfig, securityErrorHandler: " + event.text );
}	