package fr.batchass
{
	import components.Config;
	
	import flash.desktop.*;
	import flash.events.*;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.utils.Timer;
	
	import fr.batchass.*;
	
	import mx.core.FlexGlobals;
	
	import videopong.Clip;
	import videopong.Clips;
	import videopong.Tags;
	
	public class Convertion implements IEventDispatcher
	{
		private var dispatcher:EventDispatcher;
		private static var instance:Convertion;
		private var timer:Timer;
		public var fileToConvert:Array = new Array();
		//public var newClips:Array = new Array();
		private var startFFMpegProcess:NativeProcess;
		[Bindable]		
		public var currentFilename:String = "";
		private var currentThumb:int;
		private var thumb1:String;
		private var _status:String;
		//public var tPath:String;

		private var _busy:Boolean = false;
		private var _summary:String;
		
		[Bindable]
		public var countNew:int = 0;
		[Bindable]
		public var countDeleted:int = 0;
		[Bindable]
		public var countChanged:int = 0;
		[Bindable]
		public var countDone:int = 0;
		[Bindable]
		public var countError:int = 0;
		[Bindable]
		public var countTotal:int = 0;
		[Bindable]
		public var countNoChange:int = 0;
		public var nochgFiles:String = "";
		public var newFiles:String = "";
		public var delFiles:String = "";
		public var chgFiles:String = "";
		public var errFiles:String = "";
		public var allFiles:String = "";
		[Bindable]
		public var reso:String = "320x240";
		private var OWN_CLIPS_XML:XML;
		
		public function Convertion()
		{
			Util.log( "Conversion, constructor" );
			//status = "(0/0)";
			dispatcher = new EventDispatcher(this);
			timer = new Timer(1000);
			timer.addEventListener(TimerEvent.TIMER, processConvert);
			timer.start();
		}
		
		[Bindable]
		public function get summary():String
		{
			return _summary;
		}

		public function set summary(value:String):void
		{
			_summary = value;
		}

		[Bindable(event="busyChange")]
		public function get busy():Boolean
		{
			return _busy;
		}

		public function set busy(value:Boolean):void
		{
			if( _busy !== value)
			{
				_busy = value;
				dispatchEvent(new Event(Event.ADDED));
			}
		}

		[Bindable(event="statusChange")]
		public function get status():String
		{
			return _status;
		}

		public function set status(value:String):void
		{
			if( _status !== value)
			{
				_status = value;
				dispatchEvent(new Event(Event.CHANGE));
			}
		}

		public static function getInstance():Convertion
		{
			if (instance == null)
			{
				instance = new Convertion();
			}
			
			return instance;
		}
		
		public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			dispatcher.addEventListener(type, listener, useCapture, priority);
		}
		
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean=false):void
		{
			dispatcher.removeEventListener(type, listener, useCapture);
		}
		
		public function dispatchEvent(event:Event):Boolean
		{
			return dispatcher.dispatchEvent(event);
		}
		
		public function hasEventListener(type:String):Boolean
		{
			return dispatcher.hasEventListener(type);
		}
		
		public function willTrigger(type:String):Boolean
		{
			return dispatcher.willTrigger(type);
		}
		private function processConvert(event:Event): void 
		{
			dispatchEvent( new Event(Event.CHANGE) );
			status = "(" + countDone + "/" + countTotal + ")";
			
			var freeSpace:Number = Math.round( File.applicationStorageDirectory.spaceAvailable / 1048576 );
			if ( freeSpace < 10 )
			{
				Util.ffMpegOutputLog( "processConvert: disk has less than 10Mb free space(" + freeSpace + "), convertion cannot continue.\n" );
			}
			else
			{
				if ( !busy )
				{
					if ( fileToConvert.length > 0 )
					{
						busy = true;
						convert( fileToConvert[0] );
						fileToConvert.shift();
					}
					else
					{	
						/*if ( newClips.length > 0 )
						{
							var clips:Clips = Clips.getInstance();
							clips.addNewClip( newClips[0].clipName, newClips[0].ownXml, newClips[0].cPath );
							newClips.shift();
						}
						else
						{	*/							
							// all is converted and finished
							summary = "Completed:\n"; // [" + allFiles + "]\n";
							var availSwfs:String = newFiles + chgFiles + nochgFiles;
							var countAvail:int = countNew + countChanged + countNoChange;
							summary += "- newly indexed: " + countNew + " clip(s)";
							if ( countNew > 0 )	summary += " [" + newFiles + "]\n" else summary += "\n";
							summary += "- changed: " + countChanged + " clip(s)";
							if ( countChanged > 0 )	summary += " [" + chgFiles + "]\n" else summary += "\n";
							summary += "- deleted: " + countDeleted + " clip(s)";
							if ( countDeleted > 0 )	summary += " [" + delFiles + "]\n" else summary += "\n";
							summary += "- no change: " + countNoChange + " clip(s)";
							if ( countNoChange > 0 ) summary += " [" + nochgFiles + "]\n" else summary += "\n";
							if ( countError > 0 )
							{
								summary += "- could not convert thumbs and preview: " + countError + " clip(s) [" + errFiles + "]\n";
							}
							summary += "- available as swf: " + countAvail + " clip(s)";
							if ( countAvail > 0 ) summary += " [" + availSwfs + "]\n" else summary += "\n";

							dispatchEvent( new Event(Event.COMPLETE) );							
						//}
					}
				}
				else
				{
					//busy
					if ( !startFFMpegProcess.running ) busy = false;
				}
				
				//if ( ( fileToConvert.length == 0 ) && ( newClips.length == 0 ) )
				if ( fileToConvert.length == 0 )
				{
					busy = false;
				}				
				
			}
			
		}
		public function addFileToConvert( lstFile:File ):void
		{
			countTotal++;
			
			var clip:Clip = new Clip( lstFile );
			allFiles += clip.name + " ";
			
			var clips:Clips = Clips.getInstance();
			if ( clips.newClip( clip.clipRelativePath ) )
			{
				countNew++;
				newFiles += clip.clipGeneratedTitle + " ";
				fileToConvert.push( clip );
			}
			else
			{
				//log.text += "Clip already in db: " + clipGeneratedTitle + "\n";
				// check if file changed
				if ( clips.fileChanged( clip.clipRelativePath, FlexGlobals.topLevelApplication.ownFolderPath ) )
				{
					// delete thumbs and preview swf
					deleteThumbs( clip.thumbsPath );
					deleteFile( clip.swfPath + clip.clipGeneratedName + ".swf" );
					// modify xml
					// read clip xml file
					var localClipXMLFile:String = FlexGlobals.topLevelApplication.dbFolderPath + File.separator + clip.clipGeneratedName + ".xml" ;
					var clipXmlFile:File = new File( localClipXMLFile );
					var clipXml:XML = new XML( readTextFile( clipXmlFile ) );					
					clipXml.@datemodified = clip.clipModificationDate;
					clipXml.@size = clip.clipSize;
					
					// write the text file
					clips.writeClipXmlFile( clip.clipGeneratedName, clipXml );					
					
					// modify clips.xml
					clips.deleteClip( clip.clipGeneratedName, clip.clipRelativePath );
					// generate new files
					//newClips.push({clipName:clip.clipGeneratedName,ownXml:clipXml,cPath:clip.clipPath});
					//New
					fileToConvert.push( clip ); //TODO TO BE CHECKED
					clips.addNewClip( clip.clipGeneratedName, clipXml, clip.clipPath );
					//End new
					countChanged++;
					countDone++;
					chgFiles += clip.clipGeneratedTitle + " ";
				}
				else
				{
					countDone++;
					countNoChange++;
					nochgFiles += clip.clipGeneratedTitle + " ";
				}
			}
		}
		private function onConvertComplete(clip:Clip):void
		{
			// create XML
			OWN_CLIPS_XML = <video id={clip.clipGeneratedName} urllocal={clip.clipRelativePath} datemodified={clip.clipModificationDate} size={clip.clipSize}> 
								<urlthumb1>{clip.thumbsPath + "thumb1.jpg"}</urlthumb1>
								<urlthumb2>{clip.thumbsPath + "thumb2.jpg"}</urlthumb2>
								<urlthumb3>{clip.thumbsPath + "thumb3.jpg"}</urlthumb3>
								<urlpreview>{clip.swfPath + clip.clipGeneratedName + ".swf"}</urlpreview>
								<clip name={clip.clipGeneratedTitle} />
								<creator name={FlexGlobals.topLevelApplication.userName}/>
								<tags>
									<tag name="own"/>
								</tags>
							</video>;
			var tags:Tags = Tags.getInstance();
			tags.addTagIfNew( "own" );
			if ( clip.clipRelativePath.length > 0 )
			{
				var folders:Array = clip.clipRelativePath.split( File.separator );
				
				for each (var folder:String in folders)
				{
					if ( clip.clipGeneratedTitle == folder) folder = clip.clipGeneratedTitleWithoutExtension;
					tags.addTagIfNew( folder );
					var folderXmlTag:XML = <tag name={folder} creationdate={Util.nowDate} />;
					OWN_CLIPS_XML.tags.appendChild( folderXmlTag );
				}
			}
			//newClips.push({clipName:clip.clipGeneratedName,ownXml:OWN_CLIPS_XML,cPath:clip.clipPath});
			// we now create clip XML when thumb and swf are successfully generated
			var clips:Clips = Clips.getInstance();
			//clips.addNewClip( newClips[0].clipName, newClips[0].ownXml, newClips[0].cPath );
			clips.addNewClip( clip.clipGeneratedName, OWN_CLIPS_XML, clip.clipPath );
			//newClips.shift();
		}
		
		
		
		private function processClose(event:Event):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			Util.ffMpegOutputLog( "NativeProcess processClose" );
		}

		//thumb or movie convert progress
		private function errorOutputDataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			//resetConsole();
			//configComp.log.text += data;
			if (data.indexOf("muxing overhead")>-1) 
			{
				if ( fileToConvert.length > 0 )
				{					
					thumb1 = fileToConvert[0].thumbsPath + "thumb1.jpg";
					if ( thumb1.length > 0 )
					{
						var sourceFile:File = new File( thumb1 );
						if( sourceFile.exists )
						{
							// it's a thumb (TODO verify)
							//file: copy							
							var destFile:File = new File( fileToConvert[0].thumbsPath + "thumb2.jpg" );
							sourceFile.addEventListener( IOErrorEvent.IO_ERROR, ioErrorHandler );
							sourceFile.addEventListener( SecurityErrorEvent.SECURITY_ERROR, securityErrorHandler );
							try 
							{
								sourceFile.copyTo( destFile );
								var destFile2:File = new File( fileToConvert[0].thumbsPath + "thumb3.jpg" );
								sourceFile.copyTo( destFile2 );
							}
							catch (error:Error)
							{
								Util.errorLog( "errorOutputDataHandler Error:" + error.message );
							}
						}
						else
						{
							//it's a swf movie (TODO verify)
							onConvertComplete(fileToConvert[0]);
						}
					}
				}
				busy = false;
			}
			if (data.indexOf("swf: I/O error occurred")>-1)
			{ 
				busy = false;
				// TODO verify
				countError++;
				errFiles += currentFilename + " ";
				//copySwf();
			}
			if (data.indexOf("Unknown format")>-1)
			{ 
				// TODO verify
				countError++;
				errFiles += currentFilename + " ";
				busy = false;
			}
			Util.ffMpegErrorLog( "NativeProcess errorOutputDataHandler: " + data );
		}
		public function start():void
		{
			countNew = 0;
			countDeleted = 0;
			countChanged = 0;
			countDone = 0;
			countError = 0;
			countNoChange = 0;
			countTotal = 0;
			nochgFiles = "";
			newFiles = "";
			delFiles = "";
			chgFiles = "";
			errFiles = "";
			allFiles = "";
			currentFilename = "";

		}
		public function copySwf( src:String, dest:String ):void
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
		
		// convertion
		//private function generatePreview( ownVideoPath:String, swfPath:String, clipGeneratedName:String, clipFileName:String ):void
		//private function convert( ownVideoPath:String, clipGeneratedName:String, clipFileName:String, thumb:Boolean ):void
		private function convert( clip:Clip ):void
		{
			generate( clip, true );
			generate( clip, false );
		}
		private function generate( clip:Clip, thumb:Boolean ):void
		{
			var outPath:String;
			if ( thumb )
			{
				outPath = FlexGlobals.topLevelApplication.dldFolderPath + "/thumbs/" + clip.clipGeneratedName + "/";
			}
			else
			{
				outPath = FlexGlobals.topLevelApplication.dldFolderPath + "/preview/" + clip.clipGeneratedName + "/";				
				
			}
			var outFolder:File = new File( outPath );
			// creates folder if it does not exists
			if ( !outFolder.exists ) 
			{
				// create the directory
				outFolder.createDirectory();
			}
			currentFilename = clip.clipGeneratedTitle;
			// Start the process
			if ( clip.clipPath.indexOf(".swf") > -1 )
			{
				//error no conversion on swf files
				if ( !thumb )
				{
					countError++;
					countDone++;
					errFiles += clip.clipGeneratedTitle + " ";
					copySwf( clip.clipPath, outPath + clip.clipGeneratedName + ".swf" );
				}
			}
			else
			{
				try
				{
					var ffMpegExecutable:File = File.applicationStorageDirectory.resolvePath( FlexGlobals.topLevelApplication.vpFFMpegExePath );
					if ( !ffMpegExecutable.exists )
					{
						Util.log( "convertion, ffMpegExecutable does not exist: " + FlexGlobals.topLevelApplication.vpFFMpegExePath );
					}
					else
					{
						Util.log( "convertion, ffMpegExecutable exists: " + FlexGlobals.topLevelApplication.vpFFMpegExePath );
					}
					//configComp.ffout.text += "generatePreview, converting " + clipFileName + " to swf.\n";
					Util.ffMpegOutputLog( "NativeProcess convertion: Converting " + clip.clipGeneratedName + "\n" );
					
					var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					nativeProcessStartupInfo.executable = ffMpegExecutable;
					Util.log("convertion,ff path:"+ ffMpegExecutable.nativePath );			
					var processArgs:Vector.<String> = new Vector.<String>();
					var i:int = 0;
					processArgs[i++] = "-i";
					processArgs[i++] = clip.clipPath;
					processArgs[i++] = "-b";
					processArgs[i++] = "400k";
					processArgs[i++] = "-an";
					if ( thumb ) 
					{
						processArgs[i++] = "-vframes";
						processArgs[i++] = "1";
						processArgs[i++] = "-f";
						processArgs[i++] = "image2";
						processArgs[i++] = "-vcodec";
						processArgs[i++] = "mjpeg";
						processArgs[i++] =  "-s";
						processArgs[i++] = "100x74"; //Frame size must be a multiple of 2
						processArgs[i++] =  "-ss";
						processArgs[i++] = "1";//thumbNumber.toString();
						processArgs[i++] = outPath + "thumb1.jpg";
					} 
					else 
					{
						processArgs[i++] = "-f";
						processArgs[i++] = "avm2";
						processArgs[i++] = "-s";
						processArgs[i++] = reso;// default "320x240";
						processArgs[i++] = outPath + clip.clipGeneratedName + ".swf";
					}
					processArgs[i++] = "-y";
					nativeProcessStartupInfo.arguments = processArgs;
					
					startFFMpegProcess = new NativeProcess();
					startFFMpegProcess.start(nativeProcessStartupInfo);
					startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,
						outputDataHandler);
					startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA,
						errorOutputDataHandler);
					startFFMpegProcess.addEventListener(Event.STANDARD_OUTPUT_CLOSE, processClose );
					startFFMpegProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit);				
				}
				catch (e:Error)
				{
					Util.log( "convertion, NativeProcess Error: " + e.message );
					busy = false;
				}	
			}
		}

		private function deleteThumbs( thumbsPath:String ): void 
		{
			deleteFile( thumbsPath + "thumb1.jpg" );
			deleteFile( thumbsPath + "thumb2.jpg" );
			deleteFile( thumbsPath + "thumb3.jpg" );
		}
		public function deleteFile( path:String ): void 
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
		private function outputDataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardOutput.readUTFBytes(process.standardOutput.bytesAvailable);
			//resetConsole();
			//configComp.log.text += data;
			Util.ffMpegOutputLog( "NativeProcess outputDataHandler: " + data );
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
		private function onExit(evt:NativeProcessExitEvent):void
		{
			Util.ffMpegOutputLog( "Process ended with code: " + evt.exitCode); 
		}
		
	}//class end
}//package end