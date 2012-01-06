package fr.batchass
{
	import components.Config;
	
	import flash.desktop.*;
	import flash.events.*;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.net.dns.AAAARecord;
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
		private var startFFMpegProcess:NativeProcess;
		[Bindable]		
		public var currentFilename:String = "";
		private var currentThumb:int;
		private var thumb1:String;
		private var _status:String = "";

		private var _busy:Boolean = false;
		private var _summary:String = "";
		private var _progress:String = "";
		
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
		public var frame:int = 0;
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
		private var session:Session = Session.getInstance();
		
		public function Convertion()
		{
			Util.log( "Conversion, constructor" );
			dispatcher = new EventDispatcher(this);
			timer = new Timer(1000);
			timer.addEventListener(TimerEvent.TIMER, processConvert);
		}

		private function processConvert(event:Event): void 
		{
			status = countDone + "/" + countTotal;
			var freeSpace:Number = Math.round( File.applicationStorageDirectory.spaceAvailable / 1048576 );
			if ( freeSpace < 10 )
			{
				Util.ffMpegOutputLog( "processConvert: disk has less than 10Mb free space(" + freeSpace + "), convertion cannot continue." );
			}
			else
			{
				if ( !busy )
				{
					if ( fileToConvert.length > 0 )
					{
						busy = true;
						Util.convertLog( "processConvert, fileToConvert.length:" + fileToConvert.length );
						generate( fileToConvert[0], false );
					}
				}
				else
				{
					//busy
					if ( startFFMpegProcess )
					{
						if ( !startFFMpegProcess.running ) 
						{
							Util.convertLog( "processConvert, startFFMpegProcess not running, busy becomes false?" );
							
							if ( fileToConvert.length > 0 ) 
							{
								countDone++;
								writeOwnXml( fileToConvert[0] );
							}
							//TODO validate busy = false;
						}
					}
				}
				
				if ( fileToConvert.length == 0 )
				{
					if ( timer.running )
					{
						generateSummary();
					}
					busy = false;
					
					Util.log( "processConvert: disk free space: " + freeSpace );
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
				Util.convertLog( "addFileToConvert, new clip:" + clip.clipPath );
				Util.convertLog( "addFileToConvert, fileToConvert.length:" + fileToConvert.length );
			}
			else
			{
				// check if file changed
				if ( clips.fileChanged( clip.clipRelativePath, session.ownFolderPath ) )
				{
					// delete thumbs and preview swf
					deleteThumbs( clip.thumbsPath );
					deleteFile( clip.swfPath + clip.clipGeneratedName + ".swf" );
					// modify xml
					// read clip xml file
					var localClipXMLFile:String = session.dbFolderPath + File.separator + clip.clipGeneratedName + ".xml" ;
					var clipXmlFile:File = new File( localClipXMLFile );
					var clipXml:XML = new XML( readTextFile( clipXmlFile ) );					
					clipXml.@datemodified = clip.clipModificationDate;
					clipXml.@size = clip.clipSize;
					
					// write the text file
					clips.writeClipXmlFile( clip.clipGeneratedName, clipXml );					
					
					// modify clips.xml
					clips.deleteClip( clip.clipGeneratedName, clip.clipRelativePath );
					// generate new files
					fileToConvert.push( clip ); 
					Util.convertLog( "addFileToConvert, changed clip:" + clip.clipPath );
					Util.convertLog( "addFileToConvert, fileToConvert.length:" + fileToConvert.length );
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
		private function onThumb1ConvertComplete(clip:Clip):void
		{
			progress += "Thumb1 convertion completed:" + clip.clipGeneratedTitle + "\n";
			Util.convertLog( "onThumb1ConvertComplete, ThumbConvert Completed:" + clip.clipPath );
			Util.convertLog( "onThumb1ConvertComplete, fileToConvert.length:" + fileToConvert.length );
			generate( clip, true, 2, Math.min( clip.maxFrame , 2400 ) );
		}
		private function onThumb2ConvertComplete(clip:Clip):void
		{
			progress += "Thumb2 convertion completed:" + clip.clipGeneratedTitle + "\n";
			Util.convertLog( "onThumb2ConvertComplete, ThumbConvert Completed:" + clip.clipPath );
			Util.convertLog( "onThumb2ConvertComplete, fileToConvert.length:" + fileToConvert.length );
			generate( clip, true, 3,  Math.min( clip.maxFrame , 3600 ) );	
		}
		private function onThumb3ConvertComplete(clip:Clip):void
		{
			progress += "Thumb3 convertion completed:" + clip.clipGeneratedTitle + "\n";
			Util.convertLog( "onThumb3ConvertComplete, ThumbConvert Completed:" + clip.clipPath );
			Util.convertLog( "onThumb3ConvertComplete, fileToConvert.length:" + fileToConvert.length );
		}
		private function onMovieConvertComplete(clip:Clip):void
		{
			progress += "Movie convertion completed:" + clip.clipGeneratedTitle + "\n";
			Util.convertLog( "onMovieConvertComplete, MovieConvert Completed:" + clip.clipPath );
			Util.convertLog( "onMovieConvertComplete, fileToConvert.length:" + fileToConvert.length );
			if ( clip.maxFrame > 0 )
			{
				Util.convertLog( "onMovieConvertComplete, clip.maxFrame:" + clip.maxFrame );
				generate( clip, true, 1, Math.min( clip.maxFrame , 1200 ) );
			}
			else
			{
				Util.convertLog( "onMovieConvertComplete, clip.maxFrame=0, we don't generate thumbs but we write clip XML" );
				writeOwnXml( clip );
			}
			
		}
		
		private function writeOwnXml( clip:Clip ):void
		{
			// create XML
			OWN_CLIPS_XML = <video id={clip.clipGeneratedName} urllocal={clip.clipRelativePath} datemodified={clip.clipModificationDate} size={clip.clipSize}> 
								<frames>{clip.maxFrame}</frames>
								<urlthumb1>{clip.thumbsPath + "thumb1.jpg"}</urlthumb1>
								<urlthumb2>{clip.thumbsPath + "thumb2.jpg"}</urlthumb2>
								<urlthumb3>{clip.thumbsPath + "thumb3.jpg"}</urlthumb3>
								<urlpreview>{clip.swfPath + clip.clipGeneratedName + ".swf"}</urlpreview>
								<clip name={clip.clipGeneratedTitle} />
								<creator name={session.userName}/>
								<tags>
									<tag name="own"/>
								</tags>
							</video>;
			var tags:Tags = Tags.getInstance();
			//useless ? tags.addTagIfNew( "own" );
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
			// we now create clip XML when thumb and swf are successfully generated
			var clips:Clips = Clips.getInstance();
			clips.addNewClip( clip.clipGeneratedName, OWN_CLIPS_XML, clip.clipPath );	
			countDone++;
			if ( fileToConvert.length > 0 ) 
			{
				fileToConvert.shift();
				Util.convertLog( "writeOwnXml, fileToConvert.shift" );
				Util.convertLog( "writeOwnXml, fileToConvert.length:" + fileToConvert.length );
			}
			if ( fileToConvert.length == 0 ) 
			{
				// all is converted and finished
				generateSummary();				
			}
			busy = false;
		}
		private function generateSummary():void
		{
			progress = "";
			summary = "Completed:\n"; // [" + allFiles + "]\n";
			var availSwfs:String = newFiles + chgFiles + nochgFiles;
			var countAvail:int = countNew + countChanged + countNoChange;
			summary += "- new: " + countNew + " clip(s)";
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
			dispatchEvent( new Event( Event.COMPLETE ) );
			dispatchEvent( new Event( Event.CHANGE ) );	
			timer.stop();
		}
		private function processClose(event:Event):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			Util.ffMpegOutputLog( "NativeProcess processClose" );
		}

		// thumb convert progress
		private function errorThumb1DataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			var error:String = "";
			if (data.indexOf("muxing overhead")>-1) 
			{
				if ( fileToConvert.length > 0 )
				{					
					//progress = "Thumb convertion completed: " + fileToConvert[0].name + "\n";
					onThumb1ConvertComplete(fileToConvert[0]);
				}
				//loop busy = false;
			}
			if ( data.indexOf("swf: I/O error occurred")>-1 ) error = "Thumb convertion: I/O error occurred: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Unknown format")>-1 ) error = "Thumb convertion: Unknown format: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Error while opening file")>-1 ) error = "Thumb convertion: Error while opening file: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Could not open")>-1 ) error = "Thumb convertion: Could not open: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("already exists. Overwrite")>-1 ) error = "Thumb convertion: already exists. Overwrite y/N: " + fileToConvert[0].name + "\n";
			if ( error.length > 0 )
			{ 
				if ( fileToConvert.length > 0 ) progress += error;
				manageConvertError();
			}
			Util.ffMpegOutputLog( "NativeProcess errorThumbDataHandler: " + data );
		}
		// thumb convert progress
		private function errorThumb2DataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			var error:String = "";
			if (data.indexOf("muxing overhead")>-1) 
			{
				if ( fileToConvert.length > 0 )
				{					
					//progress = "Thumb convertion completed: " + fileToConvert[0].name + "\n";
					onThumb2ConvertComplete(fileToConvert[0]);
				}
			}
			if ( data.indexOf("swf: I/O error occurred")>-1 ) error = "Thumb convertion: I/O error occurred: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Unknown format")>-1 ) error = "Thumb convertion: Unknown format: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Error while opening file")>-1 ) error = "Thumb convertion: Error while opening file: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Could not open")>-1 ) error = "Thumb convertion: Could not open: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("already exists. Overwrite")>-1 ) error = "Thumb convertion: already exists. Overwrite y/N: " + fileToConvert[0].name + "\n";
			if ( error.length > 0 )
			{ 
				if ( fileToConvert.length > 0 ) progress += error;
				manageConvertError();
			}
			Util.ffMpegOutputLog( "NativeProcess errorThumbDataHandler: " + data );
		}
		// thumb convert progress
		private function errorThumb3DataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			var error:String = "";
			if (data.indexOf("muxing overhead")>-1) 
			{
				if ( fileToConvert.length > 0 )
				{					
					onThumb3ConvertComplete(fileToConvert[0]);
				}
			}
			if ( data.indexOf("swf: I/O error occurred")>-1 ) error = "Thumb convertion: I/O error occurred: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Unknown format")>-1 ) error = "Thumb convertion: Unknown format: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Error while opening file")>-1 ) error = "Thumb convertion: Error while opening file: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Could not open")>-1 ) error = "Thumb convertion: Could not open: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("already exists. Overwrite")>-1 ) error = "Thumb convertion: already exists. Overwrite y/N: " + fileToConvert[0].name + "\n";
			if ( error.length > 0 )
			{ 
				if ( fileToConvert.length > 0 ) progress += error;
				manageConvertError();
			}

			Util.ffMpegOutputLog( "NativeProcess errorThumbDataHandler: " + data );
		}
		private function manageConvertError():void
		{
			countError++;
			errFiles += currentFilename + " ";
			writeOwnXml( fileToConvert[0] );
		}
		// movie convert progress
		private function errorMovieDataHandler(event:ProgressEvent):void
		{
			var process:NativeProcess = event.target as NativeProcess;
			var data:String = process.standardError.readUTFBytes(process.standardError.bytesAvailable);
			var error:String = "";
			if (data.indexOf("muxing overhead")>-1) 
			{
				if ( fileToConvert.length > 0 )
				{					
					onMovieConvertComplete(fileToConvert[0]);
				}
			}
			if (data.indexOf("frame")>-1) 
			{
				var start:int = data.indexOf("frame") + 6;
				var end:int = data.indexOf("fps");
			
				if ( end>-1 ) 
				{	
					var frameStr:String = data.substring( start, end );
					frame = int(frameStr);
					if ( frame > fileToConvert[0].maxFrame ) fileToConvert[0].maxFrame = frame;
					dispatchEvent( new Event(Event.ADDED) );	
				}
			}
			if ( data.indexOf("swf: I/O error occurred")>-1 ) error = "Movie convertion: I/O error occurred: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Unknown format")>-1 ) error = "Movie convertion: Unknown format: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Error while opening file")>-1 ) error = "Movie convertion: Error while opening file: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("Could not open")>-1 ) error = "Movie convertion: Could not open: " + fileToConvert[0].name + "\n";
			if ( data.indexOf("already exists. Overwrite")>-1 ) error = "Movie convertion: already exists. Overwrite y/N: " + fileToConvert[0].name + "\n";
			if ( error.length > 0 )
			{ 
				if ( fileToConvert.length > 0 ) progress += error;
				manageConvertError();
			}			
			Util.ffMpegOutputLog( "NativeProcess errorMovieDataHandler: " + data );
		}
		public function start():void
		{
			frame = 0;
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
			status = "";
			summary = "";
			progress = "";
			_progress = "";
			timer.start();
		}
		public function copyFile( src:String, dest:String ):void
		{
			//Util.log( "copyFile src:" + src + ", dest:" +dest );
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
				Util.errorLog( "copyFile Error:" + error.message );
				countError++;
				errFiles += currentFilename + " ";
				writeOwnXml( fileToConvert[0] );
			}			
		}
		
		// convertion
		public function createThumb( VideoFile:File, thumbIndex:int ):void
		{
			var clip:Clip = new Clip( VideoFile );
			generate( clip, true, thumbIndex, thumbIndex * 800, false );
		}
		public function generate( clip:Clip, thumb:Boolean, thumbIndex:int = 1, thumbNumber:int = 10, addListener:Boolean = true ):void
		{
			var outPath:String;
			var outFile:String;
			if ( thumb )
			{
				outPath = session.dldFolderPath + "/thumbs/" + clip.clipGeneratedName + "/";
			}
			else
			{
				outPath = session.dldFolderPath + "/preview/" + clip.clipGeneratedName + "/";				
				
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
					copyFile( clip.clipPath, outPath + clip.clipGeneratedName + ".swf" );
					//done, no thumbs, we generate xml clip
					writeOwnXml( clip );

				}
			}
			else
			{
				try
				{
					var ffMpegExecutable:File = File.applicationStorageDirectory.resolvePath( session.vpFFMpegExePath );
					if ( !ffMpegExecutable.exists )
					{
						Util.log( "convertion, ffMpegExecutable does not exist: " + session.vpFFMpegExePath );
					}
					Util.ffMpegOutputLog( "NativeProcess convertion: Converting " + clip.clipGeneratedTitle + "\n" );
					
					var nativeProcessStartupInfo:NativeProcessStartupInfo = new NativeProcessStartupInfo();
					nativeProcessStartupInfo.executable = ffMpegExecutable;
					//Util.log("convertion,ff path:"+ ffMpegExecutable.nativePath );			
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
						processArgs[i++] = "-s";
						processArgs[i++] = "100x74"; //Frame size must be a multiple of 2
						processArgs[i++] = "-ss";
						processArgs[i++] = "00:00:0."+ thumbNumber.toString();//"hh:mm:ss[.xxx]"
						outFile = outPath + "thumb" + thumbIndex + ".jpg";
						processArgs[i++] = outFile;
					} 
					else 
					{
						processArgs[i++] = "-f";
						processArgs[i++] = "avm2";
						processArgs[i++] = "-s";
						processArgs[i++] = reso;// default "320x240";
						outFile = outPath + clip.clipGeneratedName + ".swf";
						processArgs[i++] = outFile;
					}
					processArgs[i++] = "-y";
					
					var args:String = " ";
					for each (var arg:String in processArgs)
					{
						args += arg + " ";
					}
					
					Util.convertLog( "generate, command line: " + session.vpFFMpegExePath + args );
					//test if file already exist, we abort
					var outF:File =  new File( outFile ); 
					if ( outF.exists )
					{
						Util.log( "convertion, abort because already exists: " + outF );
						countError++;
						errFiles += currentFilename + " ";
						writeOwnXml( fileToConvert[0] );
					}
					else
					{
						nativeProcessStartupInfo.arguments = processArgs;
						
						startFFMpegProcess = new NativeProcess();
						startFFMpegProcess.start(nativeProcessStartupInfo);
						startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_OUTPUT_DATA,	outputDataHandler);
						if ( thumb ) 
						{
							progress += "Thumb " + thumbIndex + " (frame " + thumbNumber + ") convertion started:" + clip.clipGeneratedTitle + "\n";
							Util.convertLog( "Thumb " + thumbIndex + " (frame " + thumbNumber + ") convertion started:" + clip.clipPath );
							if ( addListener )
							{
								if ( thumbIndex == 1 ) startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, errorThumb1DataHandler);					
								if ( thumbIndex == 2 ) startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, errorThumb2DataHandler);					
								if ( thumbIndex == 3 ) startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, errorThumb3DataHandler);									
							}
						}
						else
						{
							progress += "Movie convertion started:" + clip.clipGeneratedTitle + "\n";
							Util.convertLog( "Movie convertion started:" + clip.clipPath );
							startFFMpegProcess.addEventListener(ProgressEvent.STANDARD_ERROR_DATA, errorMovieDataHandler);						
						}
						startFFMpegProcess.addEventListener(Event.STANDARD_OUTPUT_CLOSE, processClose );
						startFFMpegProcess.addEventListener(NativeProcessExitEvent.EXIT, onExit);										
					}
				}
				catch (e:Error)
				{
					Util.errorLog( "convertion, NativeProcess Error: " + e.message );
					//TODO validate busy = false;
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
		
		[Bindable]
		public function get summary():String
		{
			return _summary;
		}
		
		public function set summary(value:String):void
		{
			_summary = value;
		}
		[Bindable]
		public function get progress():String
		{
			return _progress;
		}
		
		public function set progress(value:String):void
		{
			_progress = value;
			dispatchEvent( new Event(Event.CONNECT) );	
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